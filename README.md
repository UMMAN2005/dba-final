# Enterprise Database Architecture & Governance

This repository contains the complete implementation for the Enterprise Database Architecture & Governance final project.

## Architecture Overview
The project implements a distributed SQL Server 2022 architecture leveraging Docker Compose for containerized deployment. It consists of two isolated nodes engineered for high availability and analytical workload separation.

### Nodes & Databases
*   **Primary Node (`localhost:14333`)**: Hosts the transactional workloads (`CoreDB` and `StagingDB`).
*   **Secondary Node (`localhost:14344`)**: Hosts the analytical workloads (`ReportDB`).

### Key Features Implemented
*   **Tiered Storage & Recovery**: Databases are classified via Extended Properties (Hot, Cold, Archive) and mapped to specific Recovery Models (Full vs Simple).
*   **Automated Backups**: A tiered Backup Strategy managed via SQL Server Agent (Daily Full/Diff/Log, Weekly Full/Diff, Monthly Full).
*   **Replication Pipeline**: Near-real-time data replication via Linked Servers, coupled with a simulated midnight analytical transformation and reverse sync.
*   **Automated Maintenance**: Off-peak weekend maintenance routines covering Integrity Checks, Index Reorganization, and Statistics Updates.
*   **Resource Governance**: CPU and Memory strictly capped for analytical users during high-volume reporting windows.
*   **Advanced Monitoring**: Database Mail integration utilizing SMTP relay, with automated alerting for Deadlocks and Extended Events tracking blocked processes.
*   **Security & Encryption**: Granular SQL Server Audits, Symmetric Key column-level encryption for sensitive HR data, and an automated self-healing ownership enforcement script.

## Directory Structure
*   `docker-compose.yml`: Orchestrates the Primary and Secondary SQL Server instances.
*   `scripts/`: Contains the sequential T-SQL scripts (01-99) to deploy schemas, agent jobs, replication, maintenance, mail, governance, and security configurations.
*   `diagrams/`: Contains Mermaid markdown files illustrating the backup workflow and replication data flow.

## Deployment
To bootstrap the environment:
```bash
docker-compose up -d
```
Once the containers are running, execute the scripts sequentially in SQL Server Management Studio (SSMS) against the respective node instances.
