# Infrastructure State Analyzer (ianalyzer)

An enterprise-grade, automated infrastructure monitoring tool built with Bash and Python. 
It captures critical system metrics (CPU, RAM, Disk), tracks systemd service health, and monitors endpoint connectivity.

## Architecture
- **Bash Engine:** Handles high-speed OS-level metric collection.
- **Python Engine:** Parses metrics, evaluates thresholds, and triggers alerts.
- **Systemd Integration:** Runs completely unattended in the background via `ianalyzer.timer`.

## Deployment
Automated deployment script included for system-wide installation.

*(Full documentation and CI/CD status coming soon)*
