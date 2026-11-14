# Data Model: Secret lease for agents

## Lease (in the agent memory)

| Field | Type | Rule |
|---|---|---|
| name | String | exists in the store, not `__secret-cli.*` |
| ref | Data | permanent reference of the record at the moment of Touch ID |
| value | Data | value; not written to disk or to the log |
| end | TimeInterval | monotonic clocks; `≤ confirmedAt + 24h` |

## Transitions

```text
no lease --lease + Touch ID--> lease
lease --end passed | revoke | lock | ref different | record gone--> no lease (for the name or all)
lease --screen lock | sleep--> lease (grace ends)
agent: no grace and no lease --> the process exits
```
