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
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'AWS_Aadii', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    bat "terraform init -no-color"
                    bat "terraform plan -out=tfplan -no-color"
                }
            }
        }

        stage('Terraform Apply (Provision)') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'AWS_Aadii', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    bat "terraform apply -auto-approve -no-color tfplan"
                    
                    script {
                        // 1. Get the raw output from Terraform
                        def outputRaw = bat(script: "terraform output -raw instance_ip", returnStdout: true).trim()
                        
                        echo "Debug - Raw Output: ${outputRaw}"

                        // 2. USE REGEX to extract ONLY the IP address (Ignore weird symbols)
                        // This looks for pattern: number.number.number.number
                        def matcher = (outputRaw =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/)
                        
                        if (matcher.find()) {
                            env.INSTANCE_IP = matcher.group()
                            echo "SUCCESS: Found Clean IP: ${env.INSTANCE_IP}"
                        } else {
                            error "FAILED: Could not find an IP address in the output. Check Terraform code."
                        }
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
                         // Create inventory in Windows
                         bat "echo [web] > inventory.ini"
                         bat "echo ${env.INSTANCE_IP} >> inventory.ini"

                         // Run Ansible in WSL
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
                    bat "terraform destroy -auto-approve -no-color"
                }
            }
        }
    }
}