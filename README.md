# End to End Automation

This is a bash script and will run end to end test cases for OCP.  
Results will be stored in /root/result/ directory.

## Run

Required to set two environment variables:  
USERNAME and TOKEN of github account. 

```bash
export USERNAME=your-username
export TOKEN=your-token
```  
Can pass two optional command line arguments as:  
 -e : power environment  
 -r : repository release version  

| Commandline Arg  | Required |  Default | Possible Values |
| ------------- | ------------- | ------------- |  ------------- | 
| -e  |  No | powervm | powervm, powervs, libvirt|
| -r  | No  | 4.9 | 4.4, 4.7, 4.9, etc |  

To run using default values:  
```bash
./e2e.sh
```  
To run using custom values:  
eg.  
1. Set both environment and release
```bash
./e2e.sh -e libvirt -r 4.8
```
2. Set only release
```bash
./e2e.sh -r 4.8
```
3. Set only environment
```bash
./e2e.sh -e powervs
```
