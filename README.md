## This is a DIY. scp function . 
### When you test your script in a VM machine or a remote server , you can use it to upload your resource without input password every times.
### It use scp command ,and take care of the password. When exit ,it release/flush the password it held.

### How 2 use:

#### 1.direct run with scp params

``` 
# example:
./scpex.sh -r -P 2222 /path/to/local/dir pangu@192.168.0.17:/home/pangu/test/

``` 

#### 2.Add the fanction to your environment.

``` 
source ~/.bashrc
# or ~
source ~/.bash_profile

scpex -r -P 2222 /path/to/local/dir pangu@192.168.0.17:/home/pangu/test/

``` 