---
name: obsidian-weekly-status
description: Displays weekly accomplishment summary from Obsidian @log folder
user-invocable-as: weekly-status
tools: obsidian
---

# Obsidian Weekly Status

Generates a narrative summary of all work completed during the current week's daily logs.

## How It Works

1. Finds @log folder in Obsidian vault
2. Calculates current calendar week (Sunday-Saturday)
3. Reads all daily logs for the week
4. Parses entries with titles and detailed content
5. Groups related work intelligently by project/topic
6. Formats as narrative bullets with contextual sub-bullets

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

### Step 4: Parse Entries with Full Content

Parse each daily log to extract entries with titles, tags, and detailed content:

1. Split each log by `---` section dividers
2. For each section, extract title, tags, and full content body
3. Parse content body for bullet points and details
4. Build comprehensive entry list with source date

Implementation pseudocode:

```
PARSE_ENTRIES:
  all_entries = []

  FOR daily_log in daily_logs:
    raw_content = daily_log['content']
    date = daily_log['date']

    # Split by section dividers
    sections = split_by_regex(raw_content, r'^---$', multiline=True)

    FOR section in sections:
      # Skip empty sections
      IF section.strip() == "":
        CONTINUE

      lines = section.split('\n')

      # Extract title from header line
      header_line = lines[0] if lines else ""
      title_match = regex_search(r'#\s*<span[^>]*>([^<]+)</span>\s*\[([^\]]+)\]\s*-\s*(.+)', header_line)

      IF NOT title_match:
        CONTINUE  # Skip sections without proper header

      entry_type = title_match.group(1).strip()
      time = title_match.group(2).strip()
      title = title_match.group(3).strip()

      # Remove status markers from title
      title = remove_status_markers(title)  # Removes <mark>DONE</mark>, etc.

      # Extract all hashtags
      tag_matches = regex_findall(r'#([a-zA-Z0-9_-]+)', section)
      # Filter out hex color codes
      tags = [t for t in tag_matches if not is_hex_color(t)]
      tags = list(set(tags))  # Remove duplicates

      # Extract content body (everything after header and tags line)
      content_lines = []
      in_content = False
      FOR line in lines[1:]:  # Skip header line
        line_stripped = line.strip()
        # Skip the tags line
        IF line_stripped.startswith('#') AND all(word.startswith('#') for word in line_stripped.split()):
          in_content = True
          CONTINUE
        IF in_content AND line_stripped:
          content_lines.append(line)

      content_body = '\n'.join(content_lines).strip()

      # Parse bullet points and details from content
      details = extract_bullet_points(content_body)

      # Store entry
      entry = {
        'type': entry_type,
        'title': title,
        'tags': tags,
        'date': date,
        'details': details,  # List of bullet points/sub-items
        'raw_content': content_body
      }
      all_entries.append(entry)

  RETURN all_entries
```

Helper function to extract bullet points:

```
EXTRACT_BULLET_POINTS:
  details = []
  lines = content_body.split('\n')

  FOR line in lines:
    trimmed = line.strip()
    # Match markdown list items (-, *, •)
    IF trimmed.startswith(('-', '*', '•')):
      # Remove bullet marker
      text = trimmed[1:].strip()
      # Determine indentation level
      indent_level = count_leading_spaces(line) // 4  # Assume 4 spaces = 1 indent
      details.append({
        'text': text,
        'indent': indent_level
      })

  RETURN details
```

Example entry:
```python
{
  'type': 'TASK',
  'title': 'Patient Rx History (Full Response)',
  'tags': ['task', 'patientrxhistory'],
  'date': datetime(2026, 3, 18),
  'details': [
    {'text': 'Added branch protection to repository', 'indent': 0},
    {'text': 'Removed deprecated tables', 'indent': 1}
  ],
  'raw_content': '- Added branch protection...\n  - Removed deprecated...'
}
```

### Step 5: Group Related Work Intelligently

Analyze entries and group related work by project/topic using semantic clustering:

1. Identify project names from tags and titles
2. Merge related entries into topic groups
3. Sort by relevance and chronology

Implementation pseudocode:

```
GROUP_RELATED_WORK:
  project_groups = {}  # project_key -> list of entries

  # Define project/topic patterns (can be extended)
  project_patterns = {
    'snowflake': ['snowflake', 'snowflakeadministration', 'masking'],
    'patientrxhistory': ['patientrxhistory', 'patient rx', 'milliman'],
    'httpstonats': ['httpstonats', 'https to nats'],
    'rasdatawarehouse': ['rasdatawarehouse', 'transmission log'],
    'databricks': ['databricks', 'prx'],
  }

  # Additional patterns for people, general topics
  people_pattern = ['kris', 'carli', 'abdiel', 'kevin', 'mario', 'tom']
  meeting_pattern = ['meeting', 'discussion']

  FOR entry in all_entries:
    assigned = False

    # Check if entry matches a project pattern
    FOR project_key, keywords in project_patterns.items():
      IF any(keyword in entry['title'].lower() OR keyword in entry['tags'] for keyword in keywords):
        IF project_key not in project_groups:
          project_groups[project_key] = []
        project_groups[project_key].append(entry)
        assigned = True
        BREAK

    # If not assigned to project, check for people-specific work
    IF NOT assigned:
      FOR person in people_pattern:
        IF person in entry['tags'] OR person in entry['title'].lower():
          key = f'collaboration_{person}'
          IF key not in project_groups:
            project_groups[key] = []
          project_groups[key].append(entry)
          assigned = True
          BREAK

    # If still not assigned, check for meetings/discussions
    IF NOT assigned:
      IF any(keyword in entry['tags'] for keyword in meeting_pattern):
        key = 'meetings'
        IF key not in project_groups:
          project_groups[key] = []
        project_groups[key].append(entry)
        assigned = True

    # Fallback: place in "other" category
    IF NOT assigned:
      IF 'other' not in project_groups:
        project_groups['other'] = []
      project_groups['other'].append(entry)

  # Sort entries within each group chronologically
  FOR project_key in project_groups:
    project_groups[project_key].sort(key=lambda entry: entry['date'])

  RETURN project_groups
```

Example output:
```python
project_groups = {
  'snowflake': [entry1, entry2, entry3],
  'patientrxhistory': [entry4, entry5],
  'collaboration_kris': [entry6],
  'meetings': [entry7]
}
```

### Step 6: Format Narrative Summary

Format and output the weekly summary as narrative bullets with contextual details:

1. Build header with week date range
2. Merge related entries into narrative bullets
3. Include sub-bullets for details
4. Format as professional status report

Implementation pseudocode:

```
FORMAT_NARRATIVE_SUMMARY:
  # Calculate week range for header
  week_end = week_start + timedelta(days=6)
  header_date_range = format_date_range(week_start, week_end)
  # Example: "March 16-22, 2026"

  # Build output
  output = []
  output.append(f"📅 Weekly Summary: {header_date_range}")
  output.append("")

  # Define friendly project names
  project_names = {
    'snowflake': 'Snowflake Administration',
    'patientrxhistory': 'Patient Rx History',
    'httpstonats': 'HTTPS to NATS',
    'rasdatawarehouse': 'RAS Data Warehouse',
    'databricks': 'Databricks Integration',
    'meetings': 'Meetings & Discussions',
    'other': 'Other Tasks'
  }

  # Process each project group
  FOR project_key, entries in project_groups.items():
    # Skip empty groups
    IF len(entries) == 0:
      CONTINUE

    # Merge related entries into narrative bullets
    narrative_items = merge_into_narrative(entries)

    # Add narrative bullets with details
    FOR item in narrative_items:
      output.append(f"- {item['summary']}")

      # Add sub-bullets for details
      FOR detail in item['details']:
        indent = "    " * (detail['indent'] + 1)
        output.append(f"{indent}- {detail['text']}")

  # Print to console
  FOR line in output:
    PRINT(line)
```

Helper function to merge entries into narrative:

```
MERGE_INTO_NARRATIVE:
  narrative_items = []

  # Group entries by similarity
  # For now, each entry becomes a narrative item
  FOR entry in entries:
    summary = entry['title']

    # Extract details from entry
    details = []

    # If entry has parsed bullet points, use them
    IF entry['details']:
      details = entry['details']
    # Otherwise, parse the raw content
    ELSE IF entry['raw_content']:
      # Look for bullet points in content
      lines = entry['raw_content'].split('\n')
      FOR line in lines:
        trimmed = line.strip()
        IF trimmed.startswith(('-', '*', '•')):
          text = trimmed[1:].strip()
          indent = count_leading_spaces(line) // 4
          details.append({'text': text, 'indent': indent})

    narrative_items.append({
      'summary': summary,
      'details': details
    })

  RETURN narrative_items
```

Helper functions:

```python
def format_date_range(start, end):
  # "March 16-22, 2026"
  if start.month == end.month:
    return f"{start.strftime('%B')} {start.day}-{end.day}, {start.year}"
  else:
    return f"{start.strftime('%B %d')} - {end.strftime('%B %d, %Y')}"

def count_leading_spaces(line):
  count = 0
  for char in line:
    if char == ' ':
      count += 1
    else:
      break
  return count
```

Expected output example:
```
📅 Weekly Summary: March 16-22, 2026

- Investigated a Milliman data issue and traced one of the problematic records back to a BestRx import.
- Made progress on the PHI masking effort in the Snowflake Administration project and established the masking pattern.
    - Updated the RAS project hook into the tag resource.
- Deployed a Patient Rx History update to return the full response payload.
    - Added branch protection to the Patient Rx History repository.
    - Removed deprecated HTTPS_REQUEST_HISTORY and HTTPS_PATIENT_RX_HISTORY tables from the project.
- Completed Snowflake Administration tasks.
    - Granted the new ETC schema to the FDB read-only database roles after Mario flagged the access issue.
    - Added Carly Wagner as a Snowflake user in production.
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

- Investigated a Milliman data issue and traced one of the problematic records back to a BestRx import.
- Made progress on the PHI masking effort in the Snowflake Administration project and established the masking pattern.
    - Updated the RAS project hook into the tag resource.
- Deployed a Patient Rx History update to return the full response payload.
    - Added branch protection to the Patient Rx History repository.
    - Removed deprecated HTTPS_REQUEST_HISTORY and HTTPS_PATIENT_RX_HISTORY tables from the project.
    - Deleted 1,998,467,509 obsolete HttpsToNats staging events while preserving the Patient Rx History-related events.
- Completed Snowflake Administration tasks.
    - Granted the new ETC schema to the FDB read-only database roles after Mario flagged the access issue.
    - Added Carly Wagner as a Snowflake user in production.
    - Created a new Strand service account in Snowflake.
- Assisted Kris with the PRX share follow-up.
    - Added the PRX database to the read-only roles.
    - Helped validate the current setup approach and identified the ownership fix using USE ROLE SYSADMIN.
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

**No entries shown or incomplete output**
- Check that log sections are divided by `---`
- Verify section format includes proper header: `# <span>TYPE</span> [TIME] - Title`
- Ensure entries have meaningful content beyond just the header
- Try running `/obsidian-research` first to ensure MCP connection works

**Output format issues**
- If details/sub-bullets are missing, check that content includes markdown list items (-, *, •)
- Indentation should use 4 spaces per level for proper sub-bullet nesting
- Complex nested content may require manual formatting adjustment
