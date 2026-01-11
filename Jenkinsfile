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
                // FIXED: Using AmazonWebServicesCredentialsBinding instead of usernamePassword
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'AWS_Aadii', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    bat "terraform init"
                    bat "terraform plan -out=tfplan"
                }
            }
        }

        stage('Terraform Apply (Provision)') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'AWS_Aadii', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    bat "terraform apply -auto-approve tfplan"
                    
                    script {
                        // Capture IP
                        def ipRaw = bat(script: "terraform output -raw instance_ip", returnStdout: true).trim()
                        // Filter just the last line to get the clean IP
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

        // --- MANUAL STEP 1: CONFIGURATION ---
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
                withCredentials([sshUserPrivateKey(credentialsId: 'Aadii_new', keyFileVariable: 'SSH_KEY')]) {
                    script {
                         bat "echo [web] > inventory.ini"
                         bat "echo %INSTANCE_IP% >> inventory.ini"

                         bat """
                            @echo off
                            wsl cp \$(wslpath '%SSH_KEY%') /tmp/Aadii_new.pem
                            wsl chmod 400 /tmp/Aadii_new.pem

                            wsl ansible-playbook -i inventory.ini playbook.yml --private-key /tmp/Aadii_new.pem -u ubuntu --ssh-common-args='-o StrictHostKeyChecking=no'

                            wsl rm /tmp/Aadii_new.pem
                         """
                    }
                }
            }
        }

        // --- MANUAL STEP 2: DESTROY ---
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
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'AWS_Aadii', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    bat "terraform destroy -auto-approve"
                }
            }
        }
    }
}