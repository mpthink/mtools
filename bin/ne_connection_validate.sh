#!/usr/bin/expect -f
set hostname [lindex $argv 0]
set username [lindex $argv 1]
set password [lindex $argv 2]
set accessType [lindex $argv 3]
set rootpassword [lindex $argv 4]


if { $accessType == 1 } {
	spawn -noecho ssh -o StrictHostKeyChecking=no  -o UserKnownHostsFile=/dev/null -2 -p 22 $username@$hostname
	set timeout 10
	expect {
	  "Are you sure you want to continue connecting (yes/no)?" { send "yes\r"; exp_continue}
	   "*assword:" {send "$password\r"; exp_continue  }
	   	
	   	"Connection closed" {exit 1}
	   	"not known" {exit 1}
	   	"failures" {exit 1}
   		"Permission denied" { exit 1}
   		"Connection refused" {exit 1 }
   		
   		"Last login" {send "exit\r"  ; exit 0 }
   		"#"  {send "exit\r"  ; exit 0 }
		">"  {send "exit\r"  ; exit 0 }
		"~"  {send "exit\r"  ; exit 0 }
		"\\\$"  {send "exit\r"  ; exit 0 }
		"<"  {send "ZZZZ;\r"  ; exit 0 }
		"%"  {send "exit\r"  ; exit 0 }
		
  		timeout {
        	puts "timeout"
        	exit 2
        }
     }	
}

if { $accessType == 3 } {
	spawn -noecho ssh -o StrictHostKeyChecking=no  -o UserKnownHostsFile=/dev/null -2 -p 22 $username@$hostname
	set timeout 10
	expect {
		"Are you sure you want to continue connecting (yes/no)?" { send "yes\r"; exp_continue}
		"su*Password" {send "$rootpassword\r"; exp_continue }
		"*assword:" {send "$password\r"; exp_continue}
	   
	   	"Connection closed" {exit 1}
	   	"not known" {exit 1}
	   	"failures" {exit 3}
   		"Permission denied" { exit 3}
   		"Connection refused" {exit 3}
   		
   		"locked" {send "exit\r" ;exit 4}
		"incorrect" {send "exit\r" ;exit 4} 
		"#"  {send "exit\r"  ; exit 5 }
   		
		"\\\$"  {send "su\r"; exp_continue}
	
  		timeout {
        	puts "timeout"
        	exit 2
        }
     }	
}


if { $accessType == 2 } {
	spawn -noecho telnet $hostname
	set timeout 10
	
	expect {
		"login" {send "$username\r"; exp_continue }
		"ENTER USERNAME <" {send "$username\r"; exp_continue }
	    "*assword" {send "$password\r"; exp_continue  }
	   	"ENTER PASSWORD <" {send "$password\r"; exp_continue  }
	   	
	   	"FAILURE" {exit 1}
	   	"incorrect" {exit 1}
	   	
   		"#"  {send "exit\r"  ; exit 0 }
		">"  {send "exit\r"  ; exit 0 }
		"<"  {send "ZZZZ;\r"  ; exit 0 }
		
  		timeout { puts "timeout" ; exit 2 }
     }
}