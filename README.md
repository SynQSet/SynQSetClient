# ![SynQSetClient Logo](https://github.com/SynQSet/SynQSet/blob/main/docs/assets/logo-word.png)

**SynQSetClient** is a PowerShell module that serves as a client for the SynQSet.com application's backend.

It provides a set of cmdlets and functions to interact with SynQSetClient's API and streamline various development tasks.

## Features

- Easily connect to the SynQSet.com backend.
- Access and manipulate data and resources from the SynQSet.com application.
- Simplify automation and integration with SynQSetClient in your development workflows.

## Installation

You can install the SynQSet.com module from the PowerShell Gallery using the following command:

```powershell
Install-Module -Name SynQSetClient -Scope CurrentUser
```

## Getting Started

1. Import the module:

    ```powershell
    Import-Module SynQSetClient
    ```

2. Configure your connection to the SynQSet.com backend:

    ```PowerShell
    Set-SynQSetClientConfiguration -ApiKey <Your-API-Key> -BaseUrl <SynQSetClient-Backend-URL>
    ```

3. Start using the provided cmdlets and functions to interact with SynQSetClient.

    ```PowerShell
    # Example 1: Retrieve a list of projects

    Get-SynQSetClientProjects

    # Example 2: Create a new task

    New-SynQSetClientTask -Name "Sample Task" -Description "This is a test task"

    ```

## Contributions

Contributions are welcome! If you have ideas, bug reports, or want to contribute to the project, please see our Contribution Guidelines.

## License

This project is licensed under the [MIT License](https://alainQtec.MIT-license.org).
