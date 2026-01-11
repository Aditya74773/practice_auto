pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        TF_IN_AUTOMATION   = 'true'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init & Plan') {
            steps {
                // EXPLICITLY binding keys to standard AWS env vars to fix "Access Key Error"
                withCredentials([usernamePassword(credentialsId: 'AWS_Aadii', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    bat "terraform init"
                    bat "terraform plan -out=tfplan"
                }
            }
        }

        stage('Terraform Apply (Provision)') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'AWS_Aadii', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    bat "terraform apply -auto-approve tfplan"
                    
                    // Capture IP and save to environment variable for later stages
                    script {
                        def ipRaw = bat(script: "terraform output -raw instance_ip", returnStdout: true).trim()
                        // Clean up Windows command output artifacts if necessary
                        env.INSTANCE_IP = ipRaw.readLines().last().trim() 
                        echo "Instance IP is: ${env.INSTANCE_IP}"
                    }
                }
            }
        }

        stage('Wait for Instance Boot') {
            steps {
                echo "Waiting 60 seconds for EC2 to initialize..."
                sleep 60 
            }
        }

        // --- MANUAL STEP 1: ASK TO RUN ANSIBLE ---
        stage('Approval for Configuration') {
            input {
                message "Instance Launched (${env.INSTANCE_IP}). Install Grafana via Ansible?"
                ok "Yes, Configure"
            }
            steps {
                echo "Proceeding with Ansible..."
            }
        }

        stage('Run Ansible (WSL)') {
            steps {
                // Using your 'Aadii_new' SSH key
                withCredentials([sshUserPrivateKey(credentialsId: 'Aadii_new', keyFileVariable: 'SSH_KEY')]) {
                    script {
                         // We must generate the inventory file dynamically on Windows first
                         bat "echo [web] > inventory.ini"
                         bat "echo %INSTANCE_IP% >> inventory.ini"

                         // Pass the Windows path key to WSL and run Ansible
                         bat """
                            @echo off
                            :: 1. Copy key to a temp location in WSL so permissions work (chmod 400)
                            wsl cp \$(wslpath '%SSH_KEY%') /tmp/Aadii_new.pem
                            wsl chmod 400 /tmp/Aadii_new.pem

                            :: 2. Run Ansible Playbook using WSL
                            :: Note: We map the Windows 'inventory.ini' to the WSL path
                            wsl ansible-playbook -i inventory.ini playbook.yml --private-key /tmp/Aadii_new.pem -u ubuntu --ssh-common-args='-o StrictHostKeyChecking=no'

                            :: 3. Cleanup key
                            wsl rm /tmp/Aadii_new.pem
                         """
                    }
                }
            }
        }

        // --- MANUAL STEP 2: ASK TO DESTROY ---
        stage('Approval for Destroy') {
            input {
                message "Testing Complete. Destroy Infrastructure?"
                ok "Yes, Destroy"
            }
            steps {
                echo "Destroying..."
            }
        }

        stage('Terraform Destroy') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'AWS_Aadii', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    bat "terraform destroy -auto-approve"
                }
            }
        }
    }
}