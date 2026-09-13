# My_Marvin

A fully declarative Jenkins instance, described as code.

This project configures a Jenkins controller entirely through [Configuration as Code (JCasC)](https://plugins.jenkins.io/configuration-as-code/) and [Job DSL](https://plugins.jenkins.io/job-dsl/): users, role based authorization, folders and jobs are all generated from two files, with no manual clicking in the web UI.

## Overview

The instance ships with:

- a global system message and sign up disabled,
- four users backed by environment variables (no hardcoded secrets),
- four global roles with strictly scoped permissions,
- a `Tools` folder containing two utility jobs,
- a `SEED` job that generates fully configured build jobs for any GitHub repository.

## Repository structure

```
.
├── my_marvin.yml      # JCasC configuration (users, roles, jobs seeding, global settings)
├── job_dsl.groovy     # Job DSL script: Tools folder, clone-repository and SEED jobs
└── README.md
```

## Requirements

- Docker (recommended for local testing)
- Jenkins LTS with the following plugins: `cloudbees-folder`, `configuration-as-code`, `credentials`, `github`, `instance-identity`, `job-dsl`, `script-security`, `structs`, `role-strategy`, `ws-cleanup`

No other plugin is used: the evaluation instance only has these installed.

## Environment variables

Every password is read from the environment at startup. None of them appear in the YAML.

| Variable | User |
| --- | --- |
| `USER_CHOCOLATEEN_PASSWORD` | Hugo (`chocolateen`) |
| `USER_VAUGIE_G_PASSWORD` | Garance (`vaugie_g`) |
| `USER_I_DONT_KNOW_PASSWORD` | Jeremy (`i_dont_know`) |
| `USER_NASSO_PASSWORD` | Nassim (`nasso`) |

## Getting started

Build an image with the required plugins and point Jenkins at the configuration file:

```dockerfile
FROM jenkins/jenkins:lts

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc/my_marvin.yml

RUN jenkins-plugin-cli --plugins \
    cloudbees-folder configuration-as-code credentials github \
    instance-identity job-dsl script-security structs role-strategy ws-cleanup

USER root
RUN apt-get update && apt-get install -y gcc make && rm -rf /var/lib/apt/lists/*
USER jenkins
```

Then run it:

```bash
docker build -t my_marvin .

docker run --rm -p 8080:8080 \
  -e USER_CHOCOLATEEN_PASSWORD="..." \
  -e USER_VAUGIE_G_PASSWORD="..." \
  -e USER_I_DONT_KNOW_PASSWORD="..." \
  -e USER_NASSO_PASSWORD="..." \
  -v "$PWD/my_marvin.yml:/var/jenkins_home/casc/my_marvin.yml:ro" \
  -v "$PWD/job_dsl.groovy:/var/jenkins_home/casc/job_dsl.groovy:ro" \
  my_marvin
```

Jenkins is then available at <http://localhost:8080>, already configured. Log in with any of the four users above.

`gcc` and `make` are installed in the image so that seeded jobs can actually build and test C projects.

## Configuration

### Global

The instance greets users with:

```
Welcome to the Chocolatine-Powered Marvin Jenkins Instance.
```

Sign up is disabled: the four users defined below are the only accounts.

### Roles

Authorization uses the role based strategy. Each role is granted the minimum set of permissions needed for its purpose, and nothing more.

| Role | Description | Permissions | Assigned to |
| --- | --- | --- | --- |
| `admin` | Marvin master | Full control over the instance | Hugo |
| `ape` | Pedagogical team member | Build jobs, read their workspaces | Jeremy |
| `gorilla` | Group Obsessively Researching Innovation Linked to Learning and Accomplishment | Same as `ape`, plus create, configure, delete and move jobs, and cancel builds | Garance |
| `assist` | Assistant | Read jobs and their workspaces only | Nassim |

### Folder

`Tools` sits at the root of the dashboard and holds the utility jobs, with the description `Folder for miscellaneous tools.`

### Jobs

All jobs are freestyle jobs, enabled, and triggered manually unless stated otherwise.

#### `Tools/clone-repository`

Clones an arbitrary repository into a clean workspace.

- Parameter `GIT_REPOSITORY_URL`: Git URL of the repository to clone, no default value.
- Runs a pre build workspace cleanup, then a single shell command performing the clone.

#### `Tools/SEED`

Generates a build job for a GitHub repository from a single Job DSL text step.

- Parameter `GITHUB_NAME`: GitHub repository as `owner/repo_name`, for example `EpitechIT31000/chocolatine`.
- Parameter `DISPLAY_NAME`: name given to the generated job.

#### Seeded jobs

Jobs created by `SEED` are placed at the root of the dashboard and named after `DISPLAY_NAME`. Each one:

- exposes a GitHub project property pointing at the repository,
- takes no parameter,
- is triggered manually or by an SCM poll running every minute, which builds only when the repository changed,
- fetches the sources through the prebuilt Git SCM system,
- cleans the workspace before building,
- then runs `make fclean`, `make`, `make tests_run` and `make clean`, each in its own shell step.

## Testing

Bring the container up, log in as each of the four users in turn, and confirm that the visible actions match the role table above. A user should be able to do everything their role allows, and nothing else.

To exercise the `SEED` job, point it at any repository exposing the expected `make` rules and check that the generated job appears at the root with the right name, triggers and build steps.
