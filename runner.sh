#!/bin/bash

# Define variables
INVENTORY_FILE="inventory.ini"
PLAYBOOK_FILE="file.yml"

# Create inventory file
cat <<EOL > $INVENTORY_FILE
[all]
server1 ansible_host=your_server_ip ansible_user=your_user
EOL

# Create Ansible playbook file
cat <<EOL > $PLAYBOOK_FILE
---
- name: Install Tomcat
  hosts: all
  become: yes
  tasks:
    - name: Install Java
      apt:
        name: openjdk-11-jdk
        state: present

    - name: Create a group for Tomcat
      group:
        name: tomcat
        state: present

    - name: Create a user for Tomcat
      user:
        name: tomcat
        group: tomcat
        shell: /bin/false

    - name: Download Tomcat
      get_url:
        url: http://www-us.apache.org/dist/tomcat/tomcat-9/v9.0.50/bin/apache-tomcat-9.0.50.tar.gz
        dest: /tmp/apache-tomcat-9.0.50.tar.gz

    - name: Extract Tomcat
      unarchive:
        src: /tmp/apache-tomcat-9.0.50.tar.gz
        dest: /opt/
        remote_src: yes

    - name: Change ownership of Tomcat directory
      file:
        path: /opt/apache-tomcat-9.0.50
        owner: tomcat
        group: tomcat
        recurse: yes

    - name: Create a symbolic link to Tomcat
      file:
        src: /opt/apache-tomcat-9.0.50
        dest: /opt/tomcat
        state: link

    - name: Create a systemd service file for Tomcat
      copy:
        dest: /etc/systemd/system/tomcat.service
        content: |
          [Unit]
          Description=Apache Tomcat Web Application Container
          After=network.target

          [Service]
          Type=forking

          Environment=JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
          Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
          Environment=CATALINA_HOME=/opt/tomcat
          Environment=CATALINA_BASE=/opt/tomcat
          Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
          Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'

          ExecStart=/opt/tomcat/bin/startup.sh
          ExecStop=/opt/tomcat/bin/shutdown.sh

          User=tomcat
          Group=tomcat
          UMask=0007
          RestartSec=10
          Restart=always

          [Install]
          WantedBy=multi-user.target

    - name: Reload systemd to apply changes
      systemd:
        daemon_reload: yes

    - name: Start Tomcat service
      systemd:
        name: tomcat
        state: started
        enabled: yes
EOL

# Check if Ansible is installed
if ! [ -x "$(command -v ansible)" ]; then
  echo "Error: ansible is not installed." >&2
  exit 1
fi

# Run the Ansible playbook
ansible-playbook -i $INVENTORY_FILE $PLAYBOOK_FILE

# Check if the playbook ran successfully
if [ $? -eq 0 ]; then
  echo "Playbook executed successfully."
else
  echo "Error: Playbook execution failed." >&2
  exit 1
fi
