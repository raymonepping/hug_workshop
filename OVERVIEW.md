## Backend / Frontend / Database Setup Flow

### 1. Clone the workshop repo & prepare environment

* Open a terminal and run:

```bash
git clone https://github.com/raymonepping/hug_workshop.git
cd hug_workshop
```

* Copy example environment files and adjust for your system:

```bash
cp env_examples/_env_backend   .env.backend
cp env_examples/_env_frontend  .env.frontend
cp env_examples/_env_database  .env.database
cp env_examples/_env_root      .env
# Edit these files to match your local ports, DB choice, and credentials
```

---

### 2. Login to Terraform and register an agent on your system

* Install Terraform CLI locally.
* Authenticate your CLI:

```bash
terraform login
```

* In HCP Terraform:

  * Create or use the provided organization and project.
  * Create an Agent token and download or install the agent binary.
* On your machine:

  * Start the Terraform agent and verify it is connected to your org.
  * Make sure the agent is running on the same system where you will run the database.

*(The agent will be the execution point for your Terraform runs against your local resources.)*

---

### 3. Build Terraform to deploy your database locally via the agent

In your `hug_workshop` folder:

* Create a simple Terraform configuration that:

  * Uses the HCP Terraform backend and your organization.
  * Targets your local agent.
  * Deploys exactly one database of your choice:

    * `mysql` or `postgresql` or `mongodb` or `couchbase`
* Run:

```bash
terraform init
terraform plan
terraform apply
```

* Verify the database is reachable on the expected host and port.

---

### 4. Seed your database with the workshop dataset

From the repo root:

```bash
cd scripts
./seed_dataset.sh seed \
  --db-type postgres \
  --user workshop \
  --password workshop
```

* Adjust `--db-type`, user, password, and host flags to match the database you actually deployed.
* Confirm that the tables and sample data are present.

---

### 5. Run backend and frontend for the exercise

* Follow the exercise guide:

  * `EXERCISE.md`
    [https://github.com/raymonepping/hug_workshop/blob/main/EXERCISE.md](https://github.com/raymonepping/hug_workshop/blob/main/EXERCISE.md)

  * This walks you through:

    * Starting the backend
    * Starting the frontend
    * Pointing both at your database

* For secure database connectivity with Vault, use:

  * `ARTICLE_INDEX.md`
    [https://github.com/raymonepping/hug_workshop/blob/main/ARTICLE_INDEX.md](https://github.com/raymonepping/hug_workshop/blob/main/ARTICLE_INDEX.md)

---

### Bonus (if time left)

**Containerize your backend and frontend and deploy them with Terraform**

* Follow:

  * `CONSTRUCTION.md`
    [https://github.com/raymonepping/hug_workshop/blob/main/CONSTRUCTION.md](https://github.com/raymonepping/hug_workshop/blob/main/CONSTRUCTION.md)

* Steps at a high level:

  * Containerize backend and frontend using the provided Docker instructions.
  * Push images to a registry or use local images as appropriate.
  * Extend your Terraform configuration to:

    * Deploy the containers on the same machine where the agent runs.
    * Point the containers at your seeded database.
    * Reuse or adapt the `.env` files from `env_examples` for container configuration.
