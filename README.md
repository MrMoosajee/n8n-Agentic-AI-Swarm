[README.md](https://github.com/user-attachments/files/25097609/README.md)
# The Foundry: A Zero-Cost Autonomous Engineering Workforce

## Overview

The Foundry is an agentic AI swarm designed to be a universal, autonomous engineering workforce. It leverages a combination of cloud and local AI models, orchestrated by n8n, to take a user's request from a simple chat message to fully generated and tested code, all at zero cost.

The project is divided into several phases:
*   **Phase 1: Intake (Live)**: Converts a user's request into a Machine Readable Spec (MRS) and decides on a technology stack.
*   **Phase 2: Architecture (Planned)**: Generates a file tree and architecture documents.
*   **Phase 3: Code Gen (Planned)**: Generates the code for the project.
*   **Phase 4: Test & QA (Planned)**: Tests the generated code.

## Architecture

The Foundry uses a hybrid AI approach:
*   **Cloud AI (Free Tier)** for high-level reasoning and strategy:
    *   **Google Gemini 1.5 Pro**: Acts as the Liaison, converting user chat into an MRS.
    *   **Groq Llama 3.3 70B**: Acts as the Strategist, deciding on the technology stack.
*   **Local AI (Ollama)** for privacy-sensitive tasks:
    *   **Qwen 2.5 Coder 7B**: For code generation.
    *   **DeepSeek R1 1.5B**: For debugging.
    *   **Llama 3.2 3B**: For documentation.

### Data Flow (Phase 1)

1.  A user provides a request in a chat.
2.  The **Liaison (Gemini Pro)** converts the request into a Machine Readable Spec (MRS).
3.  The **Strategist (Llama 3.3)** decides on a technology stack based on the MRS.
4.  The MRS and stack decision are stored in a **PostgreSQL** database for the next phase.

## Tech Stack

*   **Orchestration**: n8n (Docker)
*   **Cloud AI**:
    *   Google Gemini 1.5 Pro
    *   Groq Llama 3.3 70B
*   **Local AI**:
    *   Ollama
    *   Qwen 2.5 Coder 7B
    *   DeepSeek R1 1.5B
    *   Llama 3.2 3B
*   **Data**:
    *   PostgreSQL
    *   ChromaDB (for embeddings in later phases)
*   **Hardware**: Runs on a CPU-only Linux machine.

## Getting Started

This repository contains the setup files for Phase 1 of The Foundry.

### Prerequisites

*   Docker and Docker Compose
*   API keys for Google Gemini and Groq.

### Setup

1.  Follow the detailed instructions in [`Part 1/SETUP_GUIDE.md`](./Part%201/SETUP_GUIDE.md) to set up the database and n8n credentials.

2.  Run the Foundry:
    ```bash
    docker-compose up -d
    ```

### Usage

1.  Import the n8n workflow from [`Part 1/foundry_phase1_intake_workflow.json`](./Part%201/foundry_phase1_intake_workflow.json) into your n8n instance.
2.  Trigger the workflow with a chat input to start the process.

## Project Structure

The project is organized into parts, each representing a phase of the project.

```
.
├── Part 1/             # Phase 1: Intake
│   ├── ARCHITECTURE.md
│   ├── foundry_phase1_intake_workflow.json
│   ├── init_db.sql
│   ├── setup_foundry.sh
│   ├── SETUP_GUIDE.md
│   ├── TESTING_CHECKLIST.md
│   └── TROUBLESHOOTING.md
├── Part 2/             # Phase 2: Architecture (Planned)
├── Part 3/             # Phase 3: Code Gen (Planned)
├── Part 4/             # Phase 4: Test & QA (Planned)
└── Part 5/             # (Not yet defined)
```

## Design Principles

1.  **Zero-Cost First**: All components must be free or self-hosted.
2.  **Cloud for Reasoning, Local for Privacy**: Hybrid approach for performance and security.
3.  **Version-Agnostic Integration**: Use generic APIs to avoid version lock-in.
4.  **Fail-Safe State Management**: All progress is saved to a database.
5.  **Observable & Debuggable**: Full audit trail for every agent action.

## Roadmap

*   **2026 Q1**: Phase 2 (Architecture) and Phase 3 (Code Gen).
*   **2026 Q2**: Phase 4 (Testing), Phase 5 (Deployment), and self-improvement loop.
*   **2026 Q3+**: Multi-repo support, real-time collaboration, and full autonomy.

> "From Chat to Code, Zero Cost, Full Autonomy." 🏭
