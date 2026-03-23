---
name: obsidian-research
description: Analyzes today's Obsidian log and spawns research agents for tasks tagged with #claude-research
user-invocable-as: research
tools: Agent, obsidian
---

# Obsidian Research Orchestrator

This skill automates research for tasks in your Obsidian daily log.

## How It Works

1. Finds today's log file in @log folder
2. Parses tasks tagged with #claude-research
3. Spawns parallel research agents (one per task)
4. Reports progress as each completes

## Usage

Invoke with `/research` in Claude Code.

## Implementation

### Step 1: Find Obsidian Vault with @log Folder

Use the Obsidian MCP to find the vault containing the @log folder:

1. Call `list_files_in_vault` tool to get vault root
2. Search for `@log` directory within vault
3. If not found, return error: "Could not find Obsidian vault with @log folder"
4. If found, store vault root path and @log path

Example implementation logic:

```
FIND_VAULT:
  TRY:
    files = obsidian_mcp.list_files_in_vault()
    FOR each file in files:
      # Use path separator to avoid false matches like "changelog.md"
      IF file.path contains "/@log/" OR file.path starts_with "@log/":
        # Extract vault root by removing the @log portion and everything after it
        vault_root = extract_root_path(file.path)  # e.g., /path/to/vault
        # Store the directory path to @log folder (not a file path)
        log_folder = extract_log_directory(file.path)  # e.g., /path/to/vault/@log
        RETURN (vault_root, log_folder)
    RETURN ERROR: "No @log folder found"
  CATCH mcp_error:
    RETURN ERROR: "Cannot connect to Obsidian. Verify Obsidian is running and REST API plugin is enabled."
```

Continue to next step only if vault found successfully.

### Step 2: Read Today's Log File

Construct today's log file path and read content:

1. Get current date in YYYY-MM-DD format (e.g., "2026-03-22")
2. Construct path: `{log_folder}/{date}.md`
3. Use Obsidian MCP `get_file_contents` to read file
4. If file not found, return: "No log file found for {date}"
5. If found, store content for parsing

Example implementation logic:

```
READ_LOG:
  date = get_current_date_YYYY_MM_DD()  # e.g., "2026-03-22"
  log_path = f"{log_folder}/{date}.md"  # e.g., "@log/2026-03-22.md"

  TRY:
    content = obsidian_mcp.get_file_contents(log_path)
    IF content is empty:
      RETURN ERROR: "Log file for {date} is empty"
    RETURN (log_path, content)
  CATCH file_not_found:
    RETURN ERROR: "No log file found for {date}"
```

### Step 3: Parse Tasks with #claude-research Tag

Parse log content to extract research tasks:

1. Split content by `---` dividers to identify sections
2. For each section, check if it contains `#claude-research` tag
3. **Skip tasks that already have `#claude-research-result` tag** (research already completed)
4. Extract task header (matches pattern: `# <span...>TITLE</span>`)
5. Extract task content (everything between dividers)
6. Build task list with: title, content, section header

Example regex patterns:

- Header pattern: `#\s*<span[^>]*>([^<]+)</span>[^#]*#claude-research`
- Section divider: `^---$`

Example implementation logic:

```
PARSE_TASKS:
  sections = split_by_regex(content, r'^---$')
  tasks = []
  skipped_count = 0

  FOR each section in sections:
    IF "#claude-research" in section:
      # Skip tasks that already have research results
      IF "#claude-research-result" in section OR "#claude-research-error" in section:
        skipped_count += 1
        CONTINUE  # Skip this task - research already completed

      header_match = regex_search(r'#\s*<span[^>]*>([^<]+)</span>', section)
      IF header_match:
        title = clean_html(header_match.group(1))

        # Extract content (remove header and tags)
        content_lines = section.split('\n')[1:]  # Skip header line
        content = '\n'.join(content_lines).strip()

        task = {
          'title': title,
          'content': content,
          'section_header': header_match.group(0),
          'log_path': log_path
        }
        tasks.append(task)

  IF skipped_count > 0:
    OUTPUT: "Skipped {skipped_count} task(s) with existing research results"

  IF len(tasks) == 0 AND skipped_count == 0:
    RETURN ERROR: "No research tasks found for today"

  IF len(tasks) == 0 AND skipped_count > 0:
    RETURN INFO: "All research tasks already completed"

  RETURN tasks
```

**Important:**
- Preserve original section structure for later Obsidian patching
- Skip tasks with `#claude-research-result` or `#claude-research-error` to avoid duplicate research
- Inform user about skipped tasks for transparency

### Step 4: Spawn Research Agents

For each parsed task, spawn a dedicated research agent:

1. Iterate through task list
2. For each task, call Agent tool with:
   - `subagent_type: "obsidian-research-agent"`
   - `name: "research-task-{index}"` (e.g., "research-task-1")
   - `prompt`: Structured prompt with task details
3. Spawn all agents in parallel (single tool call with multiple agents)
4. Set up agent completion handlers

Example implementation logic:

```
SPAWN_AGENTS:
  agent_calls = []

  FOR index, task in enumerate(tasks):
    agent_name = f"research-task-{index + 1}"

    prompt = f"""
Research Task Analysis

**Task Title:** {task['title']}

**Task Description:**
{task['content']}

**Log File Path:** {task['log_path']}

**Your Mission:**
1. Infer the project this task refers to from the description
2. Search /Users/dlopez/Documents/Development/Projects/ for the project
3. If found: analyze project state and create comprehensive research report
4. If not found: create error report
5. Write report to {{project}}/.claude/research/research-{{uuid}}.md
6. Update Obsidian task with results

**Base Project Path:** /Users/dlopez/Documents/Development/Projects/

Follow the obsidian-research-agent workflow.
"""

    agent_call = {
      'description': f"Research: {task['title'][:40]}...",
      'subagent_type': 'obsidian-research-agent',
      'name': agent_name,
      'prompt': prompt
    }
    agent_calls.append(agent_call)

  # Spawn all agents in parallel
  INVOKE_PARALLEL: Agent tool with agent_calls

  # Note: Agents run in background, results streamed as they complete
```

### Step 5: Report Progress

As each agent completes, stream progress updates:

```
HANDLE_COMPLETION:
  FOR each completed_agent:
    IF agent.status == "success":
      OUTPUT: "✓ Completed research for: {agent.task_title}"
    ELSE IF agent.status == "error":
      OUTPUT: "✗ Error researching: {agent.task_title} - {agent.error_message}"

  # All agents run independently, failures don't block others
```

Expected output format:
```
Found 3 tasks with #claude-research tag
Spawning research agents...

✓ Completed research for: DataDictionary Role for Tom
✓ Completed research for: Fix authentication bug in user-service
✓ Completed research for: Optimize database query performance

All research tasks complete! Check your Obsidian log for results.
```

## Usage Example

### Prerequisites

1. Obsidian running with REST API plugin enabled
2. MCP configured at `~/.claude/.mcp.json`
3. Daily log in `@log/` folder with date format: `YYYY-MM-DD.md`

### Tag Format

In your daily log, tag tasks that need research:

```markdown
---
# <span style="color:rgb(0, 112, 192)">TODO</span> [12:32] - Fix authentication bug in user-service - <mark style="background: #BBFABBA6;">OPEN</mark>
#todo #user-service #claude-research

The login endpoint is returning 500 errors intermittently. Need to investigate the root cause and implement a fix.
---
```

### Invoking the Skill

Run: `/research`

Expected output:
```
Found 3 tasks with #claude-research tag
Spawning research agents...

✓ Completed research for: Fix authentication bug in user-service
✓ Completed research for: Optimize database query performance
✓ Completed research for: Add new payment gateway integration

All research tasks complete! Check your Obsidian log for results.
```

### Result in Obsidian

Your task will be updated with:

```markdown
---
# <span style="color:rgb(0, 112, 192)">TODO</span> [12:32] - Fix authentication bug in user-service - <mark style="background: #BBFABBA6;">OPEN</mark>
#todo #user-service #claude-research

The login endpoint is returning 500 errors intermittently. Need to investigate the root cause and implement a fix.

#### Research Results
📊 Research completed: [[.claude/research/research-a1b2c3d4-e5f6-7890-abcd-ef1234567890]]
#claude-research-result
---
```

The linked report contains comprehensive analysis with solution approaches.

## Troubleshooting

**Error: "Could not find Obsidian vault with @log folder"**
- Verify Obsidian is running
- Check that your vault has a `@log` folder
- Ensure MCP is properly configured

**Error: "No log file found for {date}"**
- Check that today's log exists in `@log/` folder
- Verify filename format is `YYYY-MM-DD.md`

**Error: "Cannot connect to Obsidian"**
- Verify Obsidian REST API plugin is enabled
- Check API key in MCP configuration
- Restart Obsidian if needed

**No tasks found**
- Ensure tasks are tagged with `#claude-research`
- Check that sections are properly divided by `---`
