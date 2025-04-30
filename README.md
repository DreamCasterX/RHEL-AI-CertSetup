## Red Hat Enterprise Linux AI Hardware Certification Test Environment Setup Tool

#### [Release Note]
2.	Support RHEL AI 1.4.x
3.	Auto update new versions from the remote repository


#### [Steps]
##### 1).  Download and install RHEL AI image on SUT
+ Create root password
  +  Check `Allow root SSH login with password`
  +  No need to create a normal user
+ Allocate at least 1.5 TB to root (/sysroot) where will store LLMs
#####  2).  Boot to OS 
+  Run the commands below
  ```bash
  git clone https://github.com/DreamCasterX/RHEL-AI-CertSetup.git
  cd RHEL-AI-CertSetup
  chmod +x RHEL-AI-CertSetup.sh
  ./ RHEL-AI-CertSetup.sh
  ```
#####  3).  Select an option from the menu
  + `Config SUT` - Register and install the required software on SUT (reboot required). 
This would be the first thing you want to do with a fresh SUT
  + `Run rhcert` - Perform a full or partial certification test
  + `Collect XML log` - Save the latest test result (.xml) to the current directory or clean 
the old test results
  + `Upgrade OS image` - Upgrade the OS image to the desired version (reboot required)




