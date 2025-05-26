# Ansible Scripts

## Checking out

### Initial
```
git clone --recurse-submodules https://github.com/bradh352/ansible-scripts && \
cd ansible-scripts && \
git config --local submodule.recurse true
```

### Updating when submodules change
```
git submodule update --remote --merge && \
git add . && \
git commit -m "update submodules to latest head"
```

## Create initial environment

```
python3 -m venv ./venv
source ./venv/bin/activate
pip3 install -r requirements.txt
```

If using password authentication (like during initial setup), install the
`sshpass` helper:
```
brew install sshpass
```
```
sudo apt-get install sshpass
```

### Initialize ansible vault password

This uses the OS keychain mechanism.  We must first populate it with the
vault master password:
```
python3 ./library/vault-keyring.py set
```

## Resuming environment
```
python3 -m venv ./venv
```

## Running the core playbook

```
ansible-playbook -vv deploy.yml -l sw1.testenv.bradhouse.dev,sw2.testenv.bradhouse.dev -i inventory/testenv
```
