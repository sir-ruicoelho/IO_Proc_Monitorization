# IO Processes Monitorization

Monitoring Process I/O in bash.

# Download and Installation
To begin using this script, choose one of the following options to get started:
* Clone the repo: `git clone https://github.com/user-cube/IO_Proc_Monitorization`
* [Fork, Clone](https://github.com/user-cube/IO_Proc_Monitorization)
* [Download](https://github.com/user-cube/IO_Proc_Monitorization/archive/master.zip)

# Basic Running
```
$ ./ioproc.sh time_value
```

## Running with multiple options

* Regular expressions: `$ ./ioproc.sh -c "your_expression" time_value`
* Minimum date: `$ ./ioproc.sh -s "Your date in Linux timestamp format" time_value`
* Maximum date: `$ ./ioproc.sh -e "Your date in Linux timestamp format" time_value`
* Selection of processes by user name: `./ioproc.sh -u "user_name" time_value`
* Number of processes: `./ioproc.sh -p number_of_processes time_value`
* Reverse `./ioproc.sh -r time_value`
* Sort and write values: `./ioproc.sh -w time_value`
* Sort on total values: `./ioproc.sh -t time_value`

Note: The last argument should be an int (time value).
