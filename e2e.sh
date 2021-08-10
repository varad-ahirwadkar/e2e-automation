#!/bin/bash 

set -x 

release_version=4.9
environment=powervm

# checks for OS environment varibles
if [ "${USERNAME}" == "" ]
then 
    echo "Github USERNAME is required. Please set it as environment variable"
    exit 1
fi

if [ "${TOKEN}" == "" ]
then 
    echo "Github authentication TOKEN is required. Please set it as environment variable"
    exit 1
fi

# Optional commandline arguments
while getopts e:r: option 
do 
 case "${option}" 
 in 
 e) if [ "${OPTARG}" != "" ]
    then
       environment=${OPTARG}
    fi
    ;; 

 r) if [ "${OPTARG}" != "" ]
    then
    release_version=${OPTARG}
    fi
    ;; 
 esac 
done 

# setting varible for openshift/origin repo
release="release-${release_version}"

# setting varible for exclude-list repo
branch="${release_version}-${environment}"
# echo $branch

export RELEASE=$release
export INVERT_EXCLUDED=https://raw.github.ibm.com/mjtarsel/simple-e2e-bash/master/invert-excluded.py?token=AACYV2VNWG7XTD6NVUQ3Q23BCYQDO 
export KUBE_TEST_REPO_LIST=/tmp/kube-test-repo-list 
export TEST_DIR=/root/test_dir/openshift_ws/src/github.com/openshift/ 
export KUBECONFIG=/root/openstack-upi/auth/kubeconfig 
export PATH=$PATH:/usr/local/go/bin 

# cleaning 
rm -rf /tmp/conformance-parallel-out*
rm -rf $TEST_DIR
rm -rf go1.16.5.linux*

echo  "install go" 

wget https://golang.org/dl/go1.16.5.linux-ppc64le.tar.gz 
tar -C /usr/local -xzf go1.16.5.linux-ppc64le.tar.gz 
yum install git make -y 
which go 

echo "Cloning openshift origin github repo" 

mkdir -p $TEST_DIR
cd $TEST_DIR 
git clone https://github.com/openshift/origin.git 
cd origin 
git checkout $RELEASE 
  
echo "Run make file" 
make WHAT=cmd/openshift-tests 

echo "Override the repos" 

cat << EOREGISTRY > /tmp/kube-test-repo-list
e2eRegistry: quay.io/multiarch-k8s-e2e
e2eVolumeRegistry: quay.io/multiarch-k8s-e2e
quayIncubator: quay.io/multiarch-k8s-e2e 
quayK8sCSI: quay.io/multiarch-k8s-e2e 
k8sCSI: quay.io/multiarch-k8s-e2e 
sigStorageRegistry: quay.io/multiarch-k8s-e2e 
dockerLibraryRegistry: quay.io/sjenning 
dockerGluster: quay.io/sjenning 
EOREGISTRY


# get exclude test cases according to release and environment
cd $TEST_DIR 
cd ..
git clone https://${USERNAME}:${TOKEN}@github.ibm.com/redstack-power/e2e-exclude-list.git
cd e2e-exclude-list
git checkout $branch
filename=$(ls *.txt)
echo $filename

cat $filename > $TEST_DIR/origin/excluded_tests

# removing exclude list repo
cd ..
rm -rf e2e-exclude-list

cd $TEST_DIR 
cd origin


echo "get excluded tests" 

curl -o invert_excluded.py $INVERT_EXCLUDED 
chmod +x invert_excluded.py 

echo "Run e2e tests" 

./openshift-tests run openshift/conformance/parallel --dry-run | ./invert_excluded.py excluded_tests > test-suite.txt 

./openshift-tests run -f ./test-suite.txt --from-repository=quay.io/multi-arch/community-e2e-images -o /tmp/conformance-parallel-out.txt --junit-dir /tmp/conformance-parallel 

sed -e 's/\"/\\"/g;s/.*/\"&\"/'  /tmp/conformance-parallel-out.txt   | awk '/Failing tests:/,EOF' | tail -n +3 | head -n -4 > failed-results.txt

# re running failed test cases maximum=5 times or it will exit if previous re run failed testcases count
# is equal to present failed testcases count
cnt=1
while [ $cnt -le 5 ]
do
   f_test="$(wc -l < "failed-results.txt")"
  ./openshift-tests run -f ./failed-results.txt --from-repository=quay.io/multi-arch/community-e2e-images -o "/tmp/conformance-parallel-out-${cnt}.txt" --junit-dir /tmp/conformance-parallel

  sed -e 's/\"/\\"/g;s/.*/\"&\"/' "/tmp/conformance-parallel-out-${cnt}.txt" | awk '/Failing tests:/,EOF' | tail -n +3 | head -n -4 > failed-results.txt
  
  if [ $f_test -eq "$(wc -l < "failed-results.txt")" ]
  then 
     break
  fi
  
  cnt=$(( $cnt + 1 ))
done

# storing output to /root/result/ directory
test_cnt=1
while :
do
    if [ ! -d "/root/result/result-${test_cnt}" ]
    then
        mkdir -p "/root/result/result-${test_cnt}"
        cp /tmp/conformance-parallel-out* /root/result/result-${test_cnt}
        break
    fi
    test_cnt=$((test_cnt+1))
done

