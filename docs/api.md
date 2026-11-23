# Edify API conventions

Edify's JSON API (`/api/v1`) and MCP endpoint (`/mcp`) let the [edify CLI](https://github.com/edifyapporg/edify-cli)
and AI assistants answer leaders' questions (#315). Follow these conventions for every endpoint and MCP tool, so
clients can rely on one shape and reviewers have something to check against.

## Authentication and scope

- Every request carries a personal access token as `Authorization: Bearer <token>`, created under
  **Settings > API Tokens** (`ApiToken`). `Api::V1::BaseController` and `EdifyMcp::TokenVerifier` check it.
- The user, and from the user the unit, come **only from the token**. No endpoint or tool takes a `unit_id`; tests
  check that one supplied is ignored (API) or refused (MCP).
- Every action is authorized with Pundit (`verify_authorized`), using the same policy the web UI uses for the same
  data. A role sees through the API exactly what it sees in the UI.
- Read endpoints require the token's `read` scope. Write endpoints (#324) will require `write`.

## Responses

- **Plain JSON, not JSON:API.** Most answers are computed (stale speakers, song tallies), not resources with ids,
  and the clients are the CLI and AI assistants, which read compact JSON best.
- **The top level echoes the parameters used**, defaults included, next to a named collection:
  `{ "months": 12, "group": null, "spoken_before": "2025-11-23", "speakers": [ ... ] }`. A single record is returned
  as its object (`GET /api/v1/meetings/2026-11-08`).
- **snake_case keys, ISO 8601 dates** (`"2026-11-08"`), enum values as their Rails names (`"sacrament_hymn"`).
- **`null`, not a missing key**, when a value is absent, so every object of a kind has the same keys.
- **No internal ids** unless a client needs one to make a follow-up request. Meetings are identified by date.
- **Lists are bounded.** A list takes `limit` (or a date or week range) with a default and a maximum; there is no
  pagination yet.

## Serializers: what clients may see

Every response object is built by a serializer in `app/serializers/`: a class whose `self.call(record)` returns a
hash, listing each field explicitly. API controllers `render json:` the result, and MCP tools return the same hash,
so both front ends always agree.

- **Allowlist only.** Never `as_json`, `to_json` or `attributes` on a model: a new column would leak.
- **Never** member notes, phone numbers, email addresses, ages, birthdates, member ids or user records (#315).
  Names, gender, age group (`primary`, `youth`, `adult`) and speaking and music history are allowed.
- The specs in `spec/serializers/` pin each serializer's exact output. Adding a field means changing its
  spec too, deliberately.

## Parameters and errors

- Whole numbers are plain digits only (`integer_param`); `"010"` is 10, and `"0x10"` or `"1_2"` are refused.
- Dates are `YYYY-MM-DD` and must be real dates.
- Enumerated parameters (`group`, `song_type`) accept the exact values listed in the error message.
- Every error has one shape, with a stable `code` and a message written for a person:

  ```json
  { "error": { "code": "invalid_request", "message": "months must be a whole number from 1 to 120." } }
  ```

  | Status | `code` | When |
  |---|---|---|
  | 401 | `invalid_token` | No token, or an unknown, revoked or expired one (with `WWW-Authenticate: Bearer`) |
  | 403 | `insufficient_scope`, `no_unit`, `forbidden` | Token lacks the scope, user has no unit, or role lacks access |
  | 404 | `not_found` | No such record or endpoint |
  | 422 | `invalid_request` | A parameter is malformed or out of range |

  On `/mcp`, token problems get the same HTTP statuses (401 with `WWW-Authenticate`, or 403), while a role without
  access or a bad argument comes back as a tool error (`isError: true`) with a message for the assistant.

## Adding an endpoint

1. Put the query in a query object under `app/utils/` when it has real logic (`Members::StaleSpeakers`,
   `Songs::RecentlySung`), or in a model scope when it doesn't (`Meeting.occurring_between`). MCP tools reuse it.
2. Add or reuse a serializer in `app/serializers/`, and pin its exact output in a spec in `spec/serializers/`.
3. Authorize with the policy the UI uses for the same data.
4. Write request specs for: a valid token, missing and revoked tokens, each role, another unit's data, an ignored
   `unit_id`, and malformed parameters.
5. Add the matching CLI command in edifyapporg/edify-cli and MCP tool in `app/mcp/edify_mcp/tools/`.

## Endpoints

| Endpoint | Roles | Parameters |
|---|---|---|
| `GET /api/v1/speakers/stale` | bishopric, clerk | `months` (1-120, 12), `limit` (1-200, 25), `group` |
| `GET /api/v1/songs/recent` | all unit roles | `weeks` (1-104, 12), `limit` (1-200, 50), `song_type` |
| `GET /api/v1/meetings` | all unit roles | `from` (today), `to` (`from` + 84 days, span at most 366) |
| `GET /api/v1/meetings/:date` | all unit roles | the meeting's date, `YYYY-MM-DD` |
| `GET /api/v1/members` | bishopric, clerk | `q` (2-100 characters; every word must appear in the name), `limit` (1-100, 25) |
| `GET /api/v1/talks` | bishopric, clerk | `speaker` (every word in the name), `purpose` (contains), `from`, `to`, `limit` (1-200, 50) |

MCP tools at `/mcp`, each answering what its endpoint answers. Access is limited to site admins until `MCP_ENABLED=true`.

| Tool | Answers like | Roles |
|---|---|---|
| `list_stale_speakers` | `GET /api/v1/speakers/stale` | bishopric, clerk |
| `list_recent_songs` | `GET /api/v1/songs/recent` | all unit roles |
| `get_meeting` | `GET /api/v1/meetings/:date` | all unit roles |
| `search_members` | `GET /api/v1/members` | bishopric, clerk |
