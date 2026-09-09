# Agentic RAG HR Policy Assistant

An intelligent HR policy email-triage prototype that combines retrieval-augmented generation (RAG), multiple specialized AI agents, and workflow-routing logic.

The system retrieves relevant policy evidence, analyzes employee requests, recommends an HR response, and identifies an appropriate Zapier-style workflow action.

## Project Overview

HR teams frequently receive repetitive questions involving sick leave, remote work, vacation, overtime, and security incidents. Manually reviewing and routing these requests can cause delays, inconsistent responses, and missed urgent escalations.

This project demonstrates how an Agentic RAG workflow can support HR teams by:

- Classifying employee requests
- Retrieving relevant internal HR policies
- Retrieving supporting business context
- Coordinating specialized AI agents
- Producing an evidence-based response
- Recommending an appropriate workflow action
- Escalating uncertain or sensitive cases for human review

The system is designed as a decision-support prototype. It recommends or simulates actions but does not claim that an external workflow was completed.

## Business Problem

Traditional language models can generate plausible responses without first consulting organizational policies. In an HR environment, this can produce inaccurate or noncompliant guidance.

This project addresses that risk by retrieving policy evidence before generating the final response. It also separates retrieval, contextual analysis, and workflow decisions across specialized agents.

Potential business benefits include:

- Faster response times
- More consistent policy guidance
- Reduced repetitive work for HR staff
- Better documentation of employee requests
- Improved escalation of urgent incidents
- Stronger human oversight of uncertain cases

## System Architecture

The solution uses three specialized agents and one coordinating team:

### 1. HR Policy Retriever Agent

Searches the internal HR policy knowledge base using TF-IDF and cosine similarity. It returns the most relevant policy excerpts and their source filenames.

### 2. External Context Retriever Agent

Retrieves supporting information related to HR automation, remote work, leave administration, and cybersecurity workflows.

External context supports the analysis but does not override internal company policy.

### 3. Workflow Decision Agent

Analyzes the request and recommends a simulated Zapier-style action, priority level, and reason.

Possible actions include:

- Draft Sick Leave Email Reply
- Create Remote Work Approval Task
- Escalate to IT Security
- Recommend HR Review

### 4. HR Policy Coordinator

Coordinates the specialized agents and combines their outputs into one structured response.

The final response contains:

1. Employee Request Classification
2. Retrieved Policy Evidence
3. Supporting Context
4. Final HR Answer
5. Recommended Zapier Action
6. Business Value
7. Risk or Failure Case

## Knowledge Sources

The prototype includes simulated internal policies covering:

- Sick leave
- Remote work
- Vacation requests
- Overtime
- Data security

It also includes a second knowledge source with supporting context about:

- HR automation
- Remote-work workflows
- Leave-management workflows
- Cybersecurity incident escalation

## Technologies Used

- Python
- Agno
- OpenAI API
- GPT-4o Mini
- Scikit-learn
- TF-IDF vectorization
- Cosine similarity
- NumPy
- JSON
- Google Colab
- Zapier-style workflow-routing logic

## Test Scenarios

The system was tested using employee questions such as:

- “How many sick days do employees receive?”
- “Can I work remotely next Friday?”
- “I think I clicked a phishing link. What should I do?”

These scenarios evaluate policy retrieval, multi-agent coordination, response generation, workflow selection, and urgent security escalation.

## Key Design Principles

- Retrieve evidence before generating an answer
- Give internal organizational policies priority
- Separate responsibilities across specialized agents
- Include source filenames with retrieved evidence
- Escalate weak or missing evidence to human HR review
- Distinguish recommended actions from completed actions
- Keep humans involved in sensitive employment decisions

## Limitations

This is an educational prototype rather than a production HR system.

Current limitations include:

- The policy documents are simulated and stored within the notebook.
- TF-IDF retrieval relies primarily on keyword similarity.
- The Zapier actions are recommendations and are not executed through a live integration.
- The system depends on an external language-model API.
- The prototype does not include authentication or role-based access control.
- Employee data privacy, regulatory compliance, and security controls would require further development.
- Responses should be reviewed by qualified HR personnel before being used for employment decisions.

## Future Improvements

Future development could include:

- Moving policy documents into an external vector database
- Using semantic embeddings for improved retrieval
- Connecting the system to a live Zapier workflow
- Adding email and ticketing-system integrations
- Creating an HR review and approval interface
- Adding confidence thresholds and automated escalation rules
- Implementing authentication and role-based access
- Recording decisions in a structured audit log
- Evaluating retrieval accuracy and workflow-routing performance
- Adding safeguards for sensitive employee information

## Repository Files

- [Jupyter Notebook](./agentic-rag-hr-policy-assistant.ipynb) — Complete implementation and test scenarios
- [Project Report](./Agentic_RAG_Multi_Agent_Workflows_Report.pdf) — Detailed project documentation and workflow screenshots

## Running the Notebook

1. Open the notebook in Google Colab or Jupyter Notebook.
2. Install the required packages:

```bash
pip install agno openai duckduckgo-search ddgs scikit-learn pandas numpy
```

3. Obtain an OpenAI API key.
4. Enter the API key only when prompted securely by the notebook.
5. Run the cells sequentially.
6. Review the responses generated for the included test scenarios.

## Security Notice

Never save an OpenAI API key directly in the notebook or commit it to GitHub. Use environment variables, Colab Secrets, or a secure prompt such as `getpass`.

## Author

**Gerald Hlabiso**

- [Portfolio](https://gerald-hlabiso.github.io/business-analytics-portfolio/)
- [LinkedIn](https://www.linkedin.com/in/gerald-hlabiso)
