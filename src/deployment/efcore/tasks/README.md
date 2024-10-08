# EF Core Pipeline Steps

## Contents

- [Prerequisites](#prerequisites) - Requirements to use pipeline tasks
- [Build.yaml](#buildyaml) - Build Migration Scripts
- [Publish.yaml](#publishyaml) - Publish Migrations Artifact
- [Migrate.yaml](#migrateyaml) - Run Migrations on Azure SQL

## Prerequisites

To be able to build ef core migrations in the build pipeline the dotnet tool manifest must be configured.
To do this run the following commands in the root of your code repository.

```bash
dotnet new tool-manifest
dotnet tool install dotnet-ef
git add .
git commit -m "Added dotnet tools manifest"
git push
```

Ensure the following lines are added to your build pipeline.yaml

```yaml
resources:
  repositories:
    - repository: templates
      type: git
      name: Audacia/Audacia.Build
```

For a broader understanding of yaml pipelines in azure read the following [documentation](https://docs.microsoft.com/en-us/azure/devops/pipelines/yaml-schema?view=azure-devops&tabs=schema%2Cparameter-schema#yaml-basics).

## Steps

### build.yaml

Runs the dotnet-ef tool to build an idempotent ef core migration script for the provided dbContext.

#### Parameters

| Name                |            | Description                                                                                   |
|---                  |---         | ---                                                                                           |
| dbContext           | (required) | The Database context name for the application                                                 |
| startupProject      | (optional) | The executable project that contains the appsettings.json file.                               |
| defaultProject      | (optional) | The entity framework project which contains the database context.                             |
| dotNetToolsManifest | (optional) | The location of the dotnet tools manifest. This defaults to the root of the source repository |
| workingDirectory    | (required) | The location of project that generates an executable                                          |
| displayName         | (optional) | Custom display name for if you have more than one dbContext                                   |

#### Usage

```yaml
  # Example using only DbContext
  - template: /src/deployment/efcore/build.yaml@templates
    parameters:
      dbContext: DatabaseContext
      workingDirectory: src/Audacia.Template.Api

  # Example using exact projects
  - template: /src/deployment/efcore/build.yaml@templates
    parameters:
      dbContext: DatabaseContext
      defaultProject: src/Audacia.Template.EntityFramework/Audacia.Template.EntityFramework.csproj
      startupProject: src/Audacia.Template.Api/Audacia.Template.Api.csproj
```

### publish.yaml
Publishes all EF Core migration scripts that have been built to an artifact.
Requires build.yaml to have been run at least once.

#### Parameters

| Name         |            | Description                              |
|---           |---        |---                                        |
| artifactName | (optional) | The name of the build artifact to create |
| displayName  | (optional) | Custom display name                      |

#### Usage

```yaml
  - template: /src/deployment/efcore/publish.yaml@templates
```

### migrate.yaml

Runs the EF Core migrations script for the provided DbContext on the provided SQL Server.
Requires build and publish to have been run at an earlier stage in the pipeline.

#### Parameters

| Name              |            | Description                                                   |
|---                |---         |---                                                            |
| dbContext         | (required) | Name of the DbContext                                         |
| azureSubscription | (required) | Azure Service Principle / Azure Subscription for the resource |
| sqlHostname       | (required) | SQL Server Hostname                                           |
| sqlDatabase       | (required) | Database Name on the SQL Server                               |
| sqlUser           | (required) | SQL Server Username                                           |
| sqlPassword       | (required) | SQl Server Password                                           |
| artifactName      | (optional) | The name of the build artifact to use                         |
| displayName       | (optional) | Custom display name                                           |

#### Usage

```yaml
  - template: /src/deployment/efcore/migrate.yaml@templates
    parameters:
      dbContext: DatabaseContext
      azureSubscription: 'Audacia Dev/Test'
      sqlHostname: audacia-template.database.windows.net
      sqlDatabase: Audacia.Template.Api
      sqlUser: adminuser
      sqlPassword: adminpassword
```
