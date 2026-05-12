# Dynamic Scheduling Flowchart

This document illustrates the decision process for dynamically scheduling openQA test modules based on `# Package:` metadata and affected packages from a test trigger (e.g., a package update)..

This logic is intended to filter out unrelated test modules early in the scheduling process (such as in `lib/scheduler.pm`), saving execution time and resources. For example, an update containing `azure-cli` should not trigger test modules testing `aws` related tooling, and a `firefox` update should not trigger `vim` tests.
## Decision Flow

```mermaid
flowchart TD
    Trigger[/Test Trigger: Affected Packages/] --> Evaluate                                                                           Schedule[/Initial Scheduled Test Modules/] --> Evaluate
....
    Evaluate[For each scheduled Test Module] --> HasMetadata{"Has '# Package:'\nmetadata?"}
....                                                                                                                                  HasMetadata -- No --> Include[Include Test Module\n(Fallback)]                                                                    HasMetadata -- Yes --> Extract[Extract required packages\n(e.g., 'vim')]
....
    Extract --> Match{"Are extracted packages\n(or their dependencies)\nin 'Affected Packages'?"}
....
    Match -- Yes --> Include[Include Test Module]
    Match -- No --> Exclude[Exclude Test Module]
....
    Include --> Final[/Final Scheduled Modules/]
    Exclude --> Final
```
