-- Headless Mason "update all" — the equivalent of opening :Mason and pressing U.
--
-- Why this script exists: Mason 2.x removed the older `pkg:check_new_version()`
-- callback API. There is no single built-in command to update every installed
-- package headlessly. The Mason UI's own UPDATE_ALL_PACKAGES action (see
-- lua/mason/ui/instance.lua in the mason.nvim source) works by comparing each
-- package's get_installed_version() against get_latest_version() and calling
-- pkg:install() on the ones that differ. This script reproduces exactly that.
--
-- Run with:  nvim --headless "+luafile <this-file>" +qa

local registry = require("mason-registry")
local pkgs = registry.get_installed_packages()
local outdated = {}

-- Determine which packages are behind. Mirrors check_new_package_versions() in
-- the Mason UI: a package is outdated when its installed version differs from
-- the latest available version AND the latest is actually installable.
for _, pkg in ipairs(pkgs) do
  local ok_cur, current = pcall(function() return pkg:get_installed_version() end)
  local ok_lat, latest = pcall(function() return pkg:get_latest_version() end)
  if ok_cur and ok_lat and current and latest and current ~= latest
     and pkg:is_installable({ version = latest }) then
    table.insert(outdated, { pkg = pkg, from = current, to = latest })
  end
end

print("=== OUTDATED: " .. #outdated .. " ===")
for _, o in ipairs(outdated) do
  print("OUTDATED: " .. o.pkg.name .. "  " .. o.from .. " -> " .. o.to)
end

-- Install (= update) each outdated package. install() is async and returns a
-- handle; we wait for every handle's "closed" event before exiting so the
-- headless session doesn't quit mid-download.
local pending = #outdated
local done = (#outdated == 0)
local results = {}
for _, o in ipairs(outdated) do
  local handle = o.pkg:install({ version = o.to })
  handle:once("closed", function()
    table.insert(results, (o.pkg:is_installed() and "OK" or "FAIL") .. ": " .. o.pkg.name .. " -> " .. o.to)
    pending = pending - 1
    if pending == 0 then done = true end
  end)
end

-- Generous timeout: large packages (language servers) can take a while.
vim.wait(600000, function() return done end, 200)

print("=== RESULTS ===")
for _, r in ipairs(results) do print(r) end
if #outdated == 0 then print("All packages already up to date.") end
