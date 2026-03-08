---
name: agentmail
description: >
  Send and receive email from Claude's own AgentMail inbox (gaydeceiver@agentmail.to).
  Use this skill when Claude needs to email Matt or anyone else, check for incoming
  emails, reply to threads, or manage the inbox. Triggers on: "email me", "send me an
  email", "check my agentmail", "reply to that email", "forward this", "email this to",
  "send this as an email", or any request involving sending/receiving email from Claude's
  own address. Also triggers when Claude needs to email results, reports, summaries, or
  files to Matt (mattaabar@gmail.com). All commands run on the user's Mac Mini via
  shell:run_command.
---

# AgentMail — Claude's Email (gaydeceiver@agentmail.to)

Claude has its own email address: **gaydeceiver@agentmail.to** (display name: "Gay Deceiver").
Matt's email: **mattaabar@gmail.com**

## Authentication

The API key is stored locally. Load it before every API call:

```bash
AGENTMAIL_KEY=$(cat ~/.agents/skills/agentmail/.env_dir/api_key.txt)
```

Shell state doesn't persist between `shell:run_command` calls, so load the key in every command.

## API Base

All endpoints: `https://api.agentmail.to/v0`
Auth header: `Authorization: Bearer $AGENTMAIL_KEY`

## Inbox ID

The inbox ID is the email address itself: `gaydeceiver@agentmail.to`

## Common Operations

### Send an email

```bash
AGENTMAIL_KEY=$(cat ~/.agents/skills/agentmail/.env_dir/api_key.txt)
curl -s -X POST "https://api.agentmail.to/v0/inboxes/gaydeceiver@agentmail.to/messages/send" \
  -H "Authorization: Bearer $AGENTMAIL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "recipient@example.com",
    "subject": "Subject here",
    "text": "Plain text body",
    "html": "<p>HTML body</p>"
  }'
```

**Always send both `text` and `html` for best deliverability.**

### List threads (check inbox)

```bash
AGENTMAIL_KEY=$(cat ~/.agents/skills/agentmail/.env_dir/api_key.txt)
curl -s "https://api.agentmail.to/v0/inboxes/gaydeceiver@agentmail.to/threads" \
  -H "Authorization: Bearer $AGENTMAIL_KEY" | python3 -m json.tool
```

Optional query params: `?limit=10`, `?labels=unreplied`

### Get a specific thread

```bash
AGENTMAIL_KEY=$(cat ~/.agents/skills/agentmail/.env_dir/api_key.txt)
curl -s "https://api.agentmail.to/v0/inboxes/gaydeceiver@agentmail.to/threads/THREAD_ID" \
  -H "Authorization: Bearer $AGENTMAIL_KEY" | python3 -m json.tool
```

### List messages

```bash
AGENTMAIL_KEY=$(cat ~/.agents/skills/agentmail/.env_dir/api_key.txt)
curl -s "https://api.agentmail.to/v0/inboxes/gaydeceiver@agentmail.to/messages?limit=10" \
  -H "Authorization: Bearer $AGENTMAIL_KEY" | python3 -m json.tool
```

### Read a specific message

```bash
AGENTMAIL_KEY=$(cat ~/.agents/skills/agentmail/.env_dir/api_key.txt)
curl -s "https://api.agentmail.to/v0/inboxes/gaydeceiver@agentmail.to/messages/MESSAGE_ID" \
  -H "Authorization: Bearer $AGENTMAIL_KEY" | python3 -m json.tool
```

Use `extracted_text` or `extracted_html` fields for reply content (strips quoted history).

### Reply to a message

```bash
AGENTMAIL_KEY=$(cat ~/.agents/skills/agentmail/.env_dir/api_key.txt)
curl -s -X POST "https://api.agentmail.to/v0/inboxes/gaydeceiver@agentmail.to/messages/MESSAGE_ID/reply" \
  -H "Authorization: Bearer $AGENTMAIL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": ["sender@example.com"],
    "text": "Reply text",
    "html": "<p>Reply HTML</p>"
  }'
```

### Forward a message

```bash
AGENTMAIL_KEY=$(cat ~/.agents/skills/agentmail/.env_dir/api_key.txt)
curl -s -X POST "https://api.agentmail.to/v0/inboxes/gaydeceiver@agentmail.to/messages/MESSAGE_ID/forward" \
  -H "Authorization: Bearer $AGENTMAIL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "recipient@example.com",
    "text": "FYI — forwarding this along."
  }'
```

### Update message labels

```bash
AGENTMAIL_KEY=$(cat ~/.agents/skills/agentmail/.env_dir/api_key.txt)
curl -s -X PATCH "https://api.agentmail.to/v0/inboxes/gaydeceiver@agentmail.to/messages/MESSAGE_ID" \
  -H "Authorization: Bearer $AGENTMAIL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "add_labels": ["replied"],
    "remove_labels": ["unreplied"]
  }'
```

## Sending attachments

Base64-encode the file and include in the `attachments` array:

```bash
AGENTMAIL_KEY=$(cat ~/.agents/skills/agentmail/.env_dir/api_key.txt)
B64=$(base64 < /path/to/file.pdf)
curl -s -X POST "https://api.agentmail.to/v0/inboxes/gaydeceiver@agentmail.to/messages/send" \
  -H "Authorization: Bearer $AGENTMAIL_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"to\": \"recipient@example.com\",
    \"subject\": \"Here is the file\",
    \"text\": \"See attached.\",
    \"html\": \"<p>See attached.</p>\",
    \"attachments\": [{
      \"content\": \"$B64\",
      \"filename\": \"file.pdf\",
      \"content_type\": \"application/pdf\"
    }]
  }"
```

## Best Practices

- Always provide both `text` and `html` for deliverability
- Use labels (`unreplied`, `replied`) to track conversation state
- When replying, update labels to prevent double-replies
- Use `extracted_text`/`extracted_html` from received messages for clean content
- For large outputs (>5KB), write to file first, then use file-based approach
- Matt's email is mattaabar@gmail.com — use this as the default "to" when emailing Matt
