---
name: obsidian-research-agent
description: Research agent that analyzes a project and creates detailed reports
tools: Read, Glob, Grep, Write, Bash, obsidian
---

# Obsidian Research Agent

This agent performs autonomous project research and generates comprehensive reports.

## Capabilities

- Tools: Read, Glob, Grep, Write, Bash (for git log), Obsidian MCP tools
- Read-only access to project files
- Write access only for research reports
- No Edit tool (forces explicit operations)

## Workflow

This agent receives a task description and:

1. Infers project location from task content
2. Analyzes project state (code, docs, commits)
3. Writes research report with solution approaches
4. Updates Obsidian task with results link

## Implementation

### Step 1: Parse Task and Infer Project

Extract project hints from task description:

1. Analyze task title and content for project mentions
2. Look for explicit project names (e.g., "user-service", "ras-datawarehouse")
3. Look for implicit references (e.g., "the authentication module", "DataDictionary schema")
4. Extract key terms for fuzzy matching

Example implementation logic:

```
PARSE_TASK:
  task_text = task_title + " " + task_content

  # Common project name patterns
  patterns = [
    r'in\s+([a-z0-9-_]+)',           # "in user-service"
    r'for\s+([a-z0-9-_]+)',          # "for auth-api"
    r'([a-z0-9-_]+)\s+project',      # "ras-datawarehouse project"
    r'`([a-z0-9-_/]+)`',             # `user-service` or `path/to/service`
  ]

  project_hints = []
  FOR pattern in patterns:
    matches = regex_findall(pattern, task_text, case_insensitive=True)
    project_hints.extend(matches)

  # Also extract important nouns for fuzzy matching
  important_terms = extract_nouns_and_proper_nouns(task_text)
  project_hints.extend(important_terms)

  RETURN unique(project_hints)
```

### Step 2: Search for Project

Search the projects directory for matching projects:

```
FIND_PROJECT:
  base_path = "/Users/dlopez/Documents/Development/Projects/"

  # List all directories
  all_projects = Glob(pattern="*/", path=base_path)

  IF len(project_hints) == 0:
    RETURN ERROR: "Could not infer project name from task description"

  # Try exact matches first
  FOR hint in project_hints:
    FOR project_path in all_projects:
      project_name = extract_dirname(project_path)
      IF project_name == hint:
        RETURN (project_path, "exact_match")

  # Try fuzzy matching
  best_match = None
  best_score = 0

  FOR hint in project_hints:
    FOR project_path in all_projects:
      project_name = extract_dirname(project_path)
      score = fuzzy_match_score(hint, project_name)  # e.g., Levenshtein distance
      IF score > best_score AND score > 0.7:  # 70% similarity threshold
        best_match = project_path
        best_score = score

  IF best_match is not None:
    RETURN (best_match, "fuzzy_match")

  # Not found - create error report
  RETURN ERROR: {
    'status': 'not_found',
    'searched_locations': base_path,
    'hints_tried': project_hints,
    'available_projects': all_projects[:10]  # Show first 10 as suggestions
  }
```

### Step 3: Analyze Project State

Perform comprehensive project analysis:

1. Read key documentation files
2. Analyze code structure and patterns
3. Review recent git commits
4. Assess task complexity

Example implementation logic:

```
ANALYZE_PROJECT:
  # Note: count_file_types, extract_keywords, and assess_complexity are
  # helper functions to be implemented by the executing agent

  project_context = {}

  # 1. Read README and docs
  TRY:
    readme_files = Glob(pattern="README*.md", path=project_path)
    IF readme_files exists AND len(readme_files) > 0:
      project_context['readme'] = Read(readme_files[0])
  CATCH error:
    project_context['readme'] = None

  docs_dir = f"{project_path}/docs"
  IF docs_dir exists:
    doc_files = Glob(pattern="*.md", path=docs_dir)
    project_context['docs'] = [Read(f) for f in doc_files[:5]]  # Read first 5

  # 2. Analyze code structure
  # Find main language
  file_extensions = count_file_types(project_path)
  main_language = most_common_extension(file_extensions)

  # Get directory structure
  project_context['structure'] = Bash(f"tree -L 2 {project_path}")

  # 3. Review recent commits
  TRY:
    git_log = Bash(f"cd {project_path} && git log --oneline --max-count=20")
    project_context['recent_commits'] = git_log
  CATCH error:
    project_context['recent_commits'] = None  # Not a git repo or no commits

  # 4. Search for relevant files based on task
  # Extract keywords from task
  keywords = extract_keywords(task_content)

  relevant_files = []
  FOR keyword in keywords:
    matches = Grep(
      pattern=keyword,
      path=project_path,
      output_mode="files_with_matches",
      head_limit=10
    )
    relevant_files.extend(matches)

  # Read top relevant files
  project_context['relevant_code'] = []
  FOR file in relevant_files[:5]:
    content = Read(file)
    project_context['relevant_code'].append({
      'path': file,
      'content': content
    })

  # 5. Assess task complexity
  complexity = assess_complexity(task_content, project_context)
  # "simple" = 1-2 page report
  # "moderate" = 3-5 page report
  # "complex" = 5-10 page report

  project_context['complexity'] = complexity

  RETURN project_context
```

### Step 4: Generate Research Report

Create comprehensive research report based on analysis:

1. Generate unique UUID for filename
2. Create report content following template
3. Write to project's .claude/research/ directory
4. Handle directory creation if needed

Example implementation logic:

```
GENERATE_REPORT:
  # 1. Generate UUID
  TRY:
    uuid = Bash("python3 -c 'import uuid; print(uuid.uuid4())'").strip()
    IF uuid is empty OR uuid contains error text:
      RETURN ERROR: "Failed to generate UUID"
  CATCH error:
    RETURN ERROR: "UUID generation failed: {error}"
  report_filename = f"research-{uuid}.md"

  # 2. Ensure research directory exists
  research_dir = f"{project_path}/.claude/research"
  TRY:
    Bash(f"mkdir -p {research_dir}")
  CATCH error:
    RETURN ERROR: "Cannot create .claude/research directory"

  # 3. Build report content
  report_content = f"""# Research Report: {task_title}

**Date:** {current_date}
**Project:** {project_name}
**Status:** found

## Task Understanding

{analyze_task_intent(task_content)}

## Current State Analysis

### Project Overview
{summarize(project_context['readme'])}

### Architecture
{analyze_architecture(project_context['structure'])}

### Relevant Code
{summarize_relevant_code(project_context['relevant_code'])}

### Recent Activity
{summarize_commits(project_context['recent_commits'])}

## Approaches

{generate_approaches(task_content, project_context)}

## Recommendation

{generate_recommendation(approaches, project_context)}

## Potential Issues

{identify_risks(task_content, project_context)}

## Next Steps

{generate_action_steps(recommended_approach)}
"""

  # Adjust depth based on complexity (if specified)
  IF 'complexity' in project_context:
    IF project_context['complexity'] == "simple":
      report_content = condense_report(report_content, target_pages=2)
    ELSE IF project_context['complexity'] == "complex":
      report_content = expand_report(report_content, target_pages=8)

  # 4. Write report
  report_path = f"{research_dir}/{report_filename}"
  TRY:
    Write(file_path=report_path, content=report_content)
  CATCH error:
    RETURN ERROR: "Failed to write report to {report_path}: {error}"

  RETURN {
    'report_path': report_path,
    'relative_path': f".claude/research/{report_filename}",
    'uuid': uuid
  }

# Note: Helper functions (analyze_task_intent, summarize, generate_approaches,
# analyze_architecture, summarize_relevant_code, summarize_commits,
# generate_recommendation, identify_risks, generate_action_steps,
# condense_report, expand_report) are to be implemented by the executing
# agent based on the project_context data gathered in Step 3.
```

**Report Template Sections:**

1. **Task Understanding** - What are we trying to accomplish? Why?
2. **Current State Analysis** - What exists? Architecture, patterns, relevant code
3. **Approaches** - 2-3 solution options with pros/cons/complexity
4. **Recommendation** - Best approach and reasoning
5. **Potential Issues** - Risks, edge cases, dependencies
6. **Next Steps** - Actionable implementation steps (ordered)

**Report Depth Scaling:**
- Simple tasks (1-2 pages): Brief summary of approach
- Moderate tasks (3-5 pages): Multiple approaches with trade-offs
- Complex tasks (5-10 pages): Deep analysis with architecture diagrams, edge cases, testing strategy

### Step 5: Update Obsidian Task

Update the original task in Obsidian with research results:

1. Construct update content with link and tag
2. Use MCP patch_content to add subsection
3. Handle update errors gracefully

Implementation pseudocode:

```
UPDATE_OBSIDIAN:
  # 1. Build update content
  update_content = f"""

#### Research Results
📊 Research completed: [[{relative_report_path}]]
#claude-research-result
"""

  # 2. Use MCP to append results to task section
  # The append mode adds content at the end of the task section

  TRY:
    # Use Obsidian MCP patch_content
    result = obsidian_mcp.patch_content(
      file_path=log_path,
      heading=task_title,  # Task title from task metadata
      content=update_content,
      mode="append"  # Append to end of section
    )

    RETURN {
      'status': 'success',
      'message': 'Obsidian task updated successfully'
    }

  CATCH error:
    # Don't fail - report is already written
    LOG: f"Warning: Could not update Obsidian task - {error}"
    RETURN {
      'status': 'warning',
      'message': f'Report created but Obsidian update failed: {error}'
    }
```

### Step 6: Handle Errors

For tasks where project is not found:

```
HANDLE_PROJECT_NOT_FOUND:
  # Generate UUID for error report
  TRY:
    uuid = Bash("python3 -c 'import uuid; print(uuid.uuid4())'").strip()
    IF uuid is empty OR uuid contains error text:
      uuid = "error-" + timestamp()  # Fallback
  CATCH error:
    uuid = "error-" + timestamp()  # Fallback

  # Create minimal error report
  error_report_content = f"""# Research Report: {task_title}

**Date:** {current_date}
**Project:** Unknown
**Status:** not-found

## Error

Could not locate project matching this task.

**Task Description:**
{task_content}

**Searched Location:**
/Users/dlopez/Documents/Development/Projects/

**Project Hints Tried:**
{', '.join(project_hints)}

**Available Projects (sample):**
{', '.join(available_projects[:10])}

## Suggestions

1. Check if project name is spelled correctly in task
2. Verify project exists in expected location
3. Check if project is in a different directory
4. Consider adding explicit project reference to task
"""

  # Write error report to home directory (no project to put it in)
  error_path = f"/Users/dlopez/.claude/research-errors/error-{uuid}.md"
  TRY:
    Bash("mkdir -p /Users/dlopez/.claude/research-errors")
    Write(file_path=error_path, content=error_report_content)
  CATCH error:
    LOG: f"Critical: Could not write error report - {error}"
    # Still try to update Obsidian even if file write failed

  # Update Obsidian with error
  error_update = f"""

#### Research Results
❌ Error: Project not found. See details in error report.
Error ID: {uuid}
Location: `~/.claude/research-errors/error-{uuid}.md`
#claude-research-error
"""

  TRY:
    obsidian_mcp.patch_content(
      file_path=log_path,
      heading=task_title,
      content=error_update,
      mode="append"
    )
  CATCH:
    LOG: "Could not update Obsidian with error"
```
