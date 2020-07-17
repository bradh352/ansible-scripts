myname=`hostname -f | cut -d. -f1-2`
export PS1="[\u@${myname} \W]\\$ "
unset myname
