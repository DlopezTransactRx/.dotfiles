---
name: obsidian-weekly-status
description: Displays weekly accomplishment summary from Obsidian @log folder
user-invocable-as: weekly-status
tools: obsidian
---

# Obsidian Weekly Status

Generates a categorized summary of all entries from the current week's daily logs.

## How It Works

1. Finds @log folder in Obsidian vault
2. Calculates current calendar week (Sunday-Saturday)
3. Reads all daily logs for the week
4. Parses entries and extracts hashtags
5. Groups by tags and displays formatted summary

## Usage

Invoke with `/weekly-status` in Claude Code.

## Implementation

### Step 1: Find Obsidian Vault with @log Folder

Use the Obsidian MCP to find the vault containing the @log folder:

1. Call `list_files_in_vault` tool to get all files
2. Search for files with `@log/` in path
3. Extract vault root and @log folder path
4. Return error if not found

Implementation pseudocode:

```
FIND_VAULT:
  TRY:
    files = obsidian_mcp.list_files_in_vault()
    FOR each file in files:
      IF file.path contains "/@log/" OR file.path starts_with "@log/":
        # Extract vault root by removing @log portion
        vault_root = extract_root_before_log(file.path)
        log_folder = "@log"
        RETURN (vault_root, log_folder)
    RETURN ERROR: "Could not find Obsidian vault with @log folder"
  CATCH mcp_error:
    RETURN ERROR: "Cannot connect to Obsidian. Verify Obsidian is running and REST API plugin is enabled."
```

Continue to next step only if vault found successfully.

### Step 2: Calculate Week Boundaries

Calculate current calendar week (Sunday-Saturday):

1. Get current date
2. Calculate days since last Sunday
3. Generate list of 7 dates (Sunday through Saturday)
4. Format each as `YYYY-MM-DD.md`

Implementation pseudocode:

```
CALCULATE_WEEK:
  # Get current date
  current_date = get_current_date()

  # Python weekday: Monday=0, Sunday=6
  # We need days since Sunday: if today is Monday (0), that's 1 day since Sunday
  weekday = current_date.weekday()
  days_since_sunday = (weekday + 1) % 7

  # Calculate week start (last Sunday)
  week_start = current_date - timedelta(days=days_since_sunday)

  # Generate all 7 dates
  week_dates = []
  FOR i in range(7):
    date = week_start + timedelta(days=i)
    week_dates.append(date)

  # Format as filenames
  log_filenames = []
  FOR date in week_dates:
    filename = date.strftime("%Y-%m-%d") + ".md"
    log_filenames.append(filename)

  RETURN (week_start, week_dates, log_filenames)
```

Example output:
- Week of 2026-03-22 (Sunday): `["2026-03-16.md", "2026-03-17.md", ..., "2026-03-22.md"]`

### Step 3: Read Daily Logs

Read all available log files for the week:

1. Iterate through log filenames
2. Use Obsidian MCP `get_file_contents` for each file
3. Store content with date
4. Skip missing files silently
5. Skip empty files

Implementation pseudocode:

```
READ_LOGS:
  daily_logs = []

  FOR i, filename in enumerate(log_filenames):
    log_path = f"{log_folder}/{filename}"
    date = week_dates[i]

    TRY:
      content = obsidian_mcp.get_file_contents(log_path)

      # Skip empty files
      IF content is None OR content.strip() == "":
        CONTINUE

      daily_logs.append({
        'date': date,
        'filename': filename,
        'content': content
      })

    CATCH file_not_found:
      # Missing file is OK (no log for that day)
      CONTINUE

    CATCH mcp_error:
      # Other MCP errors should be logged but not block
      LOG: f"Warning: Could not read {log_path} - {error}"
      CONTINUE

  IF len(daily_logs) == 0:
    week_start_str = week_start.strftime("%B %d, %Y")
    RETURN ERROR: f"No log entries found for week of {week_start_str}"

  RETURN daily_logs
```

Expected: List of daily_log objects with date, filename, and content.

### Step 4: Parse Entries and Extract Tags

Parse each daily log to extract entries with metadata:

1. Split each log by `---` section dividers
2. For each section, extract title, tags, and content
3. Handle edge cases (no title, no tags)
4. Build entry list with source date

Implementation pseudocode:

```
PARSE_ENTRIES:
  all_entries = []

  FOR daily_log in daily_logs:
    content = daily_log['content']
    date = daily_log['date']

    # Split by section dividers
    sections = split_by_regex(content, r'^---$', multiline=True)

    FOR section in sections:
      # Skip empty sections
      IF section.strip() == "":
        CONTINUE

      # Extract title
      title_match = regex_search(r'#\s*<span[^>]*>([^<]+)</span>', section)
      IF title_match:
        title = clean_html(title_match.group(1))
      ELSE:
        # No title found - use first line
        first_line = section.split('\n')[0].strip()
        # Remove markdown formatting
        title = remove_markdown(first_line)
        IF title == "":
          CONTINUE  # Skip sections with no content

      # Extract all hashtags
      tag_matches = regex_findall(r'#([a-zA-Z0-9_-]+)', section)
      tags = list(set(tag_matches))  # Remove duplicates

      # Store entry
      entry = {
        'title': title,
        'tags': tags,
        'date': date,
        'content': section  # Store full content for potential future use
      }
      all_entries.append(entry)

  RETURN all_entries
```

Example entry:
```python
{
  'title': 'Fix authentication bug in user-service',
  'tags': ['todo', 'user-service', 'bug-fix'],
  'date': datetime(2026, 3, 17),
  'content': '# <span>TODO</span>...'
}
```

### Step 5: Group Entries by Tags

Organize entries by their hashtags:

1. Create tag-to-entries mapping
2. Handle entries with multiple tags (appear in each)
3. Separate untagged entries
4. Sort tags by frequency
5. Sort entries within each tag chronologically

Implementation pseudocode:

```
GROUP_BY_TAGS:
  tag_groups = {}  # tag -> list of entries
  untagged_entries = []

  FOR entry in all_entries:
    IF len(entry['tags']) == 0:
      # No tags - add to untagged
      untagged_entries.append(entry)
    ELSE:
      # Add to each tag group
      FOR tag in entry['tags']:
        IF tag not in tag_groups:
          tag_groups[tag] = []
        tag_groups[tag].append(entry)

  # Sort tags by entry count (descending)
  sorted_tags = sorted(
    tag_groups.keys(),
    key=lambda tag: len(tag_groups[tag]),
    reverse=True
  )

  # Sort entries within each tag by date
  FOR tag in tag_groups:
    tag_groups[tag].sort(key=lambda entry: entry['date'])

  # Sort untagged entries by date
  untagged_entries.sort(key=lambda entry: entry['date'])

  RETURN (sorted_tags, tag_groups, untagged_entries)
```

Example output:
```python
sorted_tags = ['project-name', 'bug-fix', 'meeting']
tag_groups = {
  'project-name': [entry1, entry2, entry3],
  'bug-fix': [entry4, entry5],
  'meeting': [entry6]
}
untagged_entries = [entry7]
```

### Step 6: Display Summary

Format and output the weekly summary to console:

1. Build header with week date range
2. Format each tag group with entries
3. Add untagged section if present
4. Add footer with totals

Implementation pseudocode:

```
DISPLAY_SUMMARY:
  # Calculate week range for header
  week_end = week_start + timedelta(days=6)
  header_date_range = format_date_range(week_start, week_end)
  # Example: "March 16-22, 2026"

  # Build output
  output = []
  output.append(f"📅 Weekly Summary: {header_date_range}")
  output.append("═" * 40)
  output.append("")

  # Add each tag group
  FOR tag in sorted_tags:
    entries = tag_groups[tag]
    count = len(entries)

    output.append(f"## #{tag} ({count} entries)")

    FOR entry in entries:
      date_str = format_entry_date(entry['date'])
      # Example: "[Mon 3/17]"
      output.append(f"  • {date_str} {entry['title']}")

    output.append("")  # Blank line between groups

  # Add untagged section if present
  IF len(untagged_entries) > 0:
    count = len(untagged_entries)
    output.append(f"## Untagged ({count} entries)")

    FOR entry in untagged_entries:
      date_str = format_entry_date(entry['date'])
      output.append(f"  • {date_str} {entry['title']}")

    output.append("")

  # Add footer
  total_entries = sum(len(tag_groups[tag]) for tag in tag_groups) + len(untagged_entries)
  days_with_entries = len(daily_logs)
  output.append("─" * 40)
  output.append(f"Total: {total_entries} entries across {days_with_entries} days")

  # Print to console
  FOR line in output:
    PRINT(line)
```

Helper functions:

```python
def format_date_range(start, end):
  # "March 16-22, 2026"
  if start.month == end.month:
    return f"{start.strftime('%B')} {start.day}-{end.day}, {start.year}"
  else:
    return f"{start.strftime('%B %d')} - {end.strftime('%B %d, %Y')}"

def format_entry_date(date):
  # "[Mon 3/17]"
  day_name = date.strftime("%a")  # Mon, Tue, etc.
  month = date.month
  day = date.day
  return f"[{day_name} {month}/{day}]"
```

Expected output example:
```
📅 Weekly Summary: March 16-22, 2026
═══════════════════════════════════════

## #project-name (5 entries)
  • [Sun 3/16] Initial project setup
  • [Mon 3/17] Implement authentication
  • [Wed 3/19] Add database integration

## #meeting (2 entries)
  • [Mon 3/16] Team standup
  • [Fri 3/21] Sprint planning

───────────────────────────────────────
Total: 7 entries across 4 days
```

## Usage Example

### Prerequisites

1. Obsidian running with REST API plugin enabled
2. MCP configured at `~/.claude/.mcp.json`
3. Daily logs in `@log/` folder with format: `YYYY-MM-DD.md`

### Log Format

Your daily logs should use `---` dividers between sections:

```markdown
---
# <span style="color:rgb(0, 112, 192)">TODO</span> [12:32] - Fix authentication bug
#todo #user-service #bug-fix

The login endpoint is returning 500 errors.
---
# <span>MEETING</span> Team standup
#meeting #daily

Discussed sprint progress and blockers.
---
```

### Invoking the Skill

Run: `/weekly-status`

Expected output:
```
📅 Weekly Summary: March 16-22, 2026
═══════════════════════════════════════

## #todo (3 entries)
  • [Mon 3/17] Fix authentication bug
  • [Tue 3/18] Update documentation
  • [Wed 3/19] Review pull requests

## #meeting (2 entries)
  • [Mon 3/16] Team standup
  • [Fri 3/21] Sprint planning

───────────────────────────────────────
Total: 5 entries across 4 days
```

## Troubleshooting

**Error: "Could not find Obsidian vault with @log folder"**
- Verify Obsidian is running
- Check that your vault has a `@log` folder
- Ensure MCP is properly configured

**Error: "No log entries found for week of {date}"**
- Check that at least one log file exists for current week
- Verify log files are in format `YYYY-MM-DD.md`
- Confirm files are in `@log/` folder

**Error: "Cannot connect to Obsidian"**
- Verify Obsidian REST API plugin is enabled
- Check API key in MCP configuration at `~/.claude/.mcp.json`
- Try restarting Obsidian

**No entries shown**
- Check that log sections are divided by `---`
- Verify section format includes title line
- Try running `/research` first to ensure MCP connection works

**Entries missing tags**
- Verify hashtags use format `#tag-name` (letters, numbers, hyphens, underscores)
- Check that tags are in the section content, not just title
- Tags are case-sensitive: `#Todo` ≠ `#todo`
