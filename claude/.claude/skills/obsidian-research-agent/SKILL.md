---
name: obsidian-research-agent
description: Research agent that performs internet research, analyzes projects, and creates detailed reports with external resources
tools: Read, Glob, Grep, Write, Bash, WebFetch, obsidian
---

# Obsidian Research Agent

This agent performs autonomous project research and generates comprehensive reports.

## Capabilities

- Tools: Read, Glob, Grep, Write, Bash (for git log), WebFetch (for internet research), Obsidian MCP tools
- Internet research via WebFetch for gathering external resources
- Wiki context integration via Obsidian MCP
- Read-only access to project files
- Write access only for research reports
- No Edit tool (forces explicit operations)

### Obsidian Tools

**Obsidian MCP Server (Primary):**
- `obsidian_list_files_in_vault` - List all files in the vault
- `obsidian_get_file_contents` - Read file contents
- `obsidian_patch_content` - Update file content with patches
- `obsidian_put_content` - Write/overwrite file content
- `obsidian_append_content` - Append to file content
- `obsidian_search` - Search vault content
- Other MCP operations exposed by the Obsidian REST API plugin

**Obsidian CLI (Fallback):**
If you need to perform operations not exposed by the MCP server, the `obsidian` CLI is available via Bash tool. Use this for operations like:
- Direct file system operations not available in MCP
- Custom Obsidian plugin interactions
- Batch operations requiring shell scripting

**Prefer MCP server when possible** - it provides structured data and better error handling.

## Workflow

This agent receives a task description and:

1. Extracts wiki-style references [[folder/name]] for additional context
2. Performs internet research to gather relevant resources and information
3. Infers project location from task content (if applicable)
4. Analyzes project state (code, docs, commits) if project found
5. Consolidates internet research, wiki context, and project analysis
6. Writes comprehensive research report with external resources
7. Updates Obsidian task with results link

## Implementation

### Step 0: Extract Wiki References and Resolve Paths

Parse the task content for Obsidian wiki-style links and resolve them to filesystem paths:

1. Search task content for `[[folder/name]]` or `[[name]]` patterns
2. Use Obsidian MCP to resolve wiki links to actual vault paths
3. Verify folders exist and are readable
4. Store resolved paths for context gathering

Example implementation logic:

```
EXTRACT_WIKI_REFERENCES:
  task_text = task_title + " " + task_content

  # Find all wiki-style links
  wiki_pattern = r'\[\[([^\]]+)\]\]'
  wiki_matches = regex_findall(wiki_pattern, task_text)

  wiki_contexts = []

  FOR each wiki_link in wiki_matches:
    # Use Obsidian MCP to resolve the link
    TRY:
      # Try to get the referenced file/folder
      resolved_files = obsidian_mcp.list_files_in_dir(wiki_link)

      IF resolved_files exists:
        # It's a folder - read all markdown files in it
        wiki_folder_path = extract_folder_path(resolved_files[0])
        markdown_files = [f for f in resolved_files if f.ends_with('.md')]

        folder_content = []
        FOR md_file in markdown_files[:10]:  # Limit to 10 files per folder
          content = obsidian_mcp.get_file_contents(md_file)
          folder_content.append({
            'file': md_file,
            'content': content
          })

        wiki_contexts.append({
          'link': wiki_link,
          'type': 'folder',
          'path': wiki_folder_path,
          'files': folder_content
        })
      ELSE:
        # Try as a single file
        content = obsidian_mcp.get_file_contents(wiki_link + '.md')
        IF content:
          wiki_contexts.append({
            'link': wiki_link,
            'type': 'file',
            'path': wiki_link + '.md',
            'content': content
          })
    CATCH error:
      # Wiki reference not found - log but don't fail
      LOG: f"Warning: Could not resolve wiki link [[{wiki_link}]] - {error}"
      CONTINUE

  IF len(wiki_contexts) > 0:
    OUTPUT: "Found {len(wiki_contexts)} wiki reference(s) for context"

  RETURN wiki_contexts
```

**Important:**
- Wiki references are optional - absence doesn't fail the research
- Multiple wiki references can be provided
- Both folder and file references are supported
- Limit file reading to prevent context overflow (max 10 files per folder)

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

### Step 1.5: Perform Internet Research

Conduct targeted web research to gather context, best practices, and relevant resources:

1. Generate search queries based on task content
2. Use WebFetch to search for relevant information
3. Extract key findings, patterns, and external resources
4. Identify relevant documentation, tutorials, and solutions

Example implementation logic:

```
PERFORM_INTERNET_RESEARCH:
  # 1. Generate targeted search queries
  queries = generate_search_queries(task_title, task_content)
  # Example queries:
  # - Main topic + "best practices"
  # - Main topic + "implementation guide"
  # - Specific technology + "tutorial"
  # - Error messages or issues from task

  internet_findings = {
    'resources': [],
    'best_practices': [],
    'implementation_guides': [],
    'related_issues': []
  }

  # 2. Perform web searches
  FOR query in queries[:5]:  # Limit to 5 searches
    TRY:
      # Use WebFetch to search
      results = WebFetch(url=f"https://www.google.com/search?q={urlencode(query)}")

      # Or use a more specific approach with direct URL fetches
      # For technical topics, prioritize:
      # - Official documentation sites
      # - Stack Overflow
      # - GitHub repos/issues
      # - Technical blogs

      # Parse results and extract relevant information
      relevant_links = extract_relevant_links(results, query)

      FOR link in relevant_links[:3]:  # Top 3 per query
        TRY:
          page_content = WebFetch(url=link)
          summary = extract_key_information(page_content, task_content)

          internet_findings['resources'].append({
            'url': link,
            'title': extract_title(page_content),
            'summary': summary,
            'relevance': calculate_relevance(summary, task_content)
          })
        CATCH error:
          LOG: f"Could not fetch {link}: {error}"
          CONTINUE

    CATCH error:
      LOG: f"Search failed for query '{query}': {error}"
      CONTINUE

  # 3. Categorize findings
  FOR resource in internet_findings['resources']:
    IF 'best practice' in resource['summary'].lower():
      internet_findings['best_practices'].append(resource)
    IF 'tutorial' in resource['summary'].lower() OR 'guide' in resource['summary'].lower():
      internet_findings['implementation_guides'].append(resource)
    IF 'issue' in resource['summary'].lower() OR 'problem' in resource['summary'].lower():
      internet_findings['related_issues'].append(resource)

  # 4. Sort by relevance
  internet_findings['resources'].sort(key=lambda x: x['relevance'], reverse=True)

  IF len(internet_findings['resources']) > 0:
    OUTPUT: "Found {len(internet_findings['resources'])} relevant internet resources"

  RETURN internet_findings

# Helper functions to implement:
def generate_search_queries(title, content):
  # Extract main topics and technologies
  # Generate focused queries like:
  # - "{technology} {action} best practices"
  # - "{framework} {specific_feature} implementation"
  # - "{error_message}" (if present in task)
  pass

def extract_relevant_links(html_content, query):
  # Parse search results HTML
  # Extract URLs from search result links
  # Filter out ads, unrelated sites
  # Prioritize: docs, stackoverflow, github, technical blogs
  pass

def extract_key_information(page_content, task_context):
  # Read page content
  # Extract relevant sections based on task context
  # Summarize key points (limit to 200-300 words per page)
  pass

def calculate_relevance(summary, task_content):
  # Calculate relevance score 0-1 based on keyword overlap
  # Consider: exact matches, semantic similarity, technical terms
  pass
```

**Important:**
- Limit web searches to avoid excessive API calls (max 5 queries, 3 links per query)
- Focus on authoritative sources (official docs, Stack Overflow, GitHub)
- Extract concise summaries - don't copy entire pages
- Handle failures gracefully - partial results are acceptable
- If all searches fail, continue with project analysis (don't fail the entire task)

**Search Query Strategies:**
- Technical implementation: "{technology} {feature} implementation guide"
- Best practices: "{topic} best practices 2024"
- Troubleshooting: "{error message}" OR "{technology} {symptom}"
- Learning: "{technology} tutorial" OR "{concept} explained"

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

### Step 3: Analyze Project State (If Project Found)

Perform comprehensive project analysis combined with wiki context:

1. Read key documentation files
2. Analyze code structure and patterns
3. Review recent git commits
4. Integrate wiki context for additional guidance
5. Cross-reference internet findings with project state
6. Assess task complexity

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

  # 5. Integrate wiki context (if available)
  IF len(wiki_contexts) > 0:
    project_context['wiki_guidance'] = []
    FOR wiki_ctx in wiki_contexts:
      IF wiki_ctx['type'] == 'folder':
        # Summarize folder contents
        summary = summarize_wiki_folder(wiki_ctx['files'])
        project_context['wiki_guidance'].append({
          'source': wiki_ctx['link'],
          'type': 'folder',
          'summary': summary,
          'key_points': extract_key_points(wiki_ctx['files'])
        })
      ELSE:  # single file
        project_context['wiki_guidance'].append({
          'source': wiki_ctx['link'],
          'type': 'file',
          'content': wiki_ctx['content']
        })

  # 6. Cross-reference internet findings with project
  IF len(internet_findings['resources']) > 0:
    # Compare project patterns with internet best practices
    alignment = compare_with_best_practices(
      project_context,
      internet_findings['best_practices']
    )
    project_context['best_practice_alignment'] = alignment

  # 7. Assess task complexity
  complexity = assess_complexity(task_content, project_context, internet_findings)
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
**Project:** {project_name if project_name else "General Research"}
**Status:** {status}

## Task Understanding

{analyze_task_intent(task_content)}

## Internet Research Findings

{format_internet_research(internet_findings)}

### Key Resources

{format_key_resources(internet_findings['resources'][:10])}

### Best Practices Identified

{format_best_practices(internet_findings['best_practices'])}

### Implementation Guides

{format_implementation_guides(internet_findings['implementation_guides'])}

{format_wiki_context_section(wiki_contexts) if wiki_contexts else ""}

## Current State Analysis

{format_project_analysis(project_context) if project_context else "No project analysis (task is general research)"}

## Approaches

{generate_approaches(task_content, project_context, internet_findings, wiki_contexts)}

## Recommendation

{generate_recommendation(approaches, project_context, internet_findings)}

## Potential Issues

{identify_risks(task_content, project_context, internet_findings)}

## Next Steps

{generate_action_steps(recommended_approach)}

## External References

{format_external_references(internet_findings['resources'])}
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

# Note: Helper functions to be implemented by the executing agent:
#
# Internet Research Functions:
# - format_internet_research() - Summarize overall internet research findings
# - format_key_resources() - Format top resources with URLs and summaries
# - format_best_practices() - List identified best practices from web research
# - format_implementation_guides() - Format tutorial/guide links and summaries
# - format_external_references() - Create reference list with all URLs
#
# Wiki Context Functions:
# - format_wiki_context_section() - Format wiki folder/file context if present
# - summarize_wiki_folder() - Summarize multiple wiki files into key themes
# - extract_key_points() - Extract actionable points from wiki content
#
# Project Analysis Functions:
# - format_project_analysis() - Format project overview, architecture, code
# - analyze_task_intent() - Understand what and why
# - generate_approaches() - Create 2-3 options using ALL context sources
# - generate_recommendation() - Best approach considering web + wiki + project
# - identify_risks() - Identify risks from all sources
# - generate_action_steps() - Ordered implementation steps
# - compare_with_best_practices() - Compare project vs internet best practices
#
# All functions should integrate: internet_findings + wiki_contexts + project_context
```

**Report Template Sections:**

1. **Task Understanding** - What are we trying to accomplish? Why?
2. **Internet Research Findings** - What information is available online? Best practices? Common patterns?
3. **Key Resources** - Relevant documentation, tutorials, Stack Overflow threads, GitHub repos
4. **Wiki Context** (if provided) - Guidance from referenced wiki folders/files
5. **Current State Analysis** (if project found) - What exists? Architecture, patterns, relevant code
6. **Approaches** - 2-3 solution options synthesizing internet + wiki + project context
7. **Recommendation** - Best approach and reasoning (considering all sources)
8. **Potential Issues** - Risks, edge cases, dependencies (from all research)
9. **Next Steps** - Actionable implementation steps (ordered, specific)
10. **External References** - Complete list of URLs consulted

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
#claude-research-result
```
📊 Research completed: [[{relative_report_path}]]
```
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

### Step 6: Handle Different Research Scenarios

The agent now handles three scenarios:

**Scenario A: Project Found + Internet Research**
- Full report with all sections (internet + wiki + project analysis)
- Most comprehensive output

**Scenario B: No Project + Internet Research Success**
- Report focuses on internet findings and wiki context
- No project-specific analysis section
- Still provides valuable research and implementation guidance
- This is NOT an error - many research tasks don't require a specific project

**Scenario C: No Project + Internet Research Failure**
- This is an error condition
- Create minimal error report with suggestions

Implementation for Scenario B (Internet-only research):

```
HANDLE_INTERNET_ONLY_RESEARCH:
  # If internet research succeeded, create a general research report
  IF len(internet_findings['resources']) > 0:
    # Generate UUID
    uuid = Bash("python3 -c 'import uuid; print(uuid.uuid4())'").strip()

    # Create general research report (no project path available)
    research_dir = "/Users/dlopez/.claude/research"
    Bash(f"mkdir -p {research_dir}")

    report_content = f"""# Research Report: {task_title}

**Date:** {current_date}
**Project:** General Research (No specific project)
**Status:** internet-research-only

## Task Understanding

{analyze_task_intent(task_content)}

## Internet Research Findings

{format_internet_research(internet_findings)}

### Key Resources

{format_key_resources(internet_findings['resources'][:10])}

### Best Practices Identified

{format_best_practices(internet_findings['best_practices'])}

### Implementation Guides

{format_implementation_guides(internet_findings['implementation_guides'])}

{format_wiki_context_section(wiki_contexts) if wiki_contexts else ""}

## Recommended Approaches

{generate_approaches_from_internet(task_content, internet_findings, wiki_contexts)}

## Implementation Steps

{generate_implementation_steps(internet_findings, wiki_contexts)}

## Potential Issues

{identify_risks_from_internet(internet_findings)}

## External References

{format_external_references(internet_findings['resources'])}

---

**Note:** This research did not identify a specific project. The findings above are based on internet research and provide general guidance for implementing the task.
"""

    # Write report to general research directory
    report_path = f"{research_dir}/research-{uuid}.md"
    Write(file_path=report_path, content=report_content)

    # Update Obsidian with success (even though no project found)
    update_content = f"""

#### Research Results
#claude-research-result
```
📊 Research completed: General research (no project-specific analysis)
Report location: `~/.claude/research/research-{uuid}.md`
```
"""

    TRY:
      obsidian_mcp.patch_content(
        file_path=log_path,
        heading=task_title,
        content=update_content,
        mode="append"
      )
    CATCH error:
      LOG: f"Warning: Could not update Obsidian - {error}"

    OUTPUT: "✓ Internet research completed (no project-specific analysis)"
    RETURN SUCCESS
```

Implementation for Scenario C (Complete Failure):

```
HANDLE_COMPLETE_FAILURE:
  # Only reach here if BOTH project not found AND internet research failed
  uuid = Bash("python3 -c 'import uuid; print(uuid.uuid4())'").strip()
  IF uuid is empty:
    uuid = "error-" + timestamp()

  error_report_content = f"""# Research Report: {task_title}

**Date:** {current_date}
**Project:** Unknown
**Status:** research-failed

## Error

Unable to complete research for this task.

**Task Description:**
{task_content}

## Issues Encountered

### Project Search
- Searched location: /Users/dlopez/Documents/Development/Projects/
- Project hints tried: {', '.join(project_hints) if project_hints else 'None extracted'}
- Available projects (sample): {', '.join(available_projects[:10]) if available_projects else 'None'}

### Internet Research
- {len(internet_findings['resources']) if internet_findings else 0} resources found
- Searches may have failed or returned insufficient results

{format_wiki_context_section(wiki_contexts) if wiki_contexts else ""}

## Suggestions

1. **Add explicit project reference**: Mention project name clearly in task
2. **Verify project exists**: Check `/Users/dlopez/Documents/Development/Projects/`
3. **Add wiki context**: Reference [[folder/name]] with relevant documentation
4. **Refine task description**: Include more specific keywords for internet search
5. **Check internet connectivity**: Ensure web searches can complete

## Partial Findings

{format_partial_findings(internet_findings) if internet_findings else "No internet findings available"}
"""

  # Write error report
  error_path = f"/Users/dlopez/.claude/research-errors/error-{uuid}.md"
  Bash("mkdir -p /Users/dlopez/.claude/research-errors")
  Write(file_path=error_path, content=error_report_content)

  # Update Obsidian with error
  error_update = f"""

#### Research Results
#claude-research-error
```
❌ Error: Research incomplete (project not found, limited internet results)
Error ID: {uuid}
Location: `~/.claude/research-errors/error-{uuid}.md`
```
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

  OUTPUT: "✗ Research failed - see error report"
  RETURN ERROR
```

**Decision Flow:**

```
START
  ↓
Extract wiki references (Step 0)
  ↓
Perform internet research (Step 1.5)
  ↓
Parse task & find project (Step 1-2)
  ↓
┌─────────────────┐
│ Project found?  │
└────┬───────┬────┘
     │Yes    │No
     │       └──→ Internet results? ─┬─→ Yes: Scenario B (internet-only)
     │                               └─→ No: Scenario C (error)
     ↓
Analyze project (Step 3)
     ↓
Generate full report (Scenario A)
     ↓
Update Obsidian
     ↓
SUCCESS
```
