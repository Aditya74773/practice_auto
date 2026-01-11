pipeline {
    agent any

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS = '-no-color'
        AWS_REGION = 'us-east-1' 
        WSL_SSH_KEY = '/home/adii_linux/.ssh/id_rsa'
    }

    stages {
        stage('Setup Environment') {
            steps {
                script {
                    // Detect branch name
                    def branch = env.GIT_BRANCH ?: env.BRANCH_NAME ?: bat(script: "@git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                    env.CLEAN_BRANCH = branch.contains('/') ? branch.split('/')[-1] : branch
                    echo "Successfully detected branch: ${env.CLEAN_BRANCH}"
                    
                    // Verify .tfvars file
                    def tfvarsFile = "${env.CLEAN_BRANCH}.tfvars"
                    def fileExists = bat(script: "@if exist ${tfvarsFile} (echo true) else (echo false)", returnStdout: true).trim()
                    
                    if (fileExists == "false") {
                        error "ABORTING: No variable file found for this branch. Please create ${tfvarsFile}."
                    }
                }
            }
        }

        stage('Terraform Initialization') {
            steps {
                withCredentials([aws(credentialsId: 'AWS_Aadii', accesskeyVariable: 'AWS_ACCESS_KEY_ID', secretkeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    bat 'terraform init'
                    bat "terraform plan -var-file=${env.CLEAN_BRANCH}.tfvars"
                }
            }
        }

        stage('Validate Apply') {
            steps {
                script {
                    if (env.CLEAN_BRANCH != 'main') {
                        input message: "Do you want to apply the plan for ${env.CLEAN_BRANCH}?", ok: "Apply"
                    } else {
                        echo "Main branch: proceeding with deployment."
                    }
                }
            }
        }

        stage('Terraform Provisioning') {
            steps {
                withCredentials([aws(credentialsId: 'AWS_Aadii', accesskeyVariable: 'AWS_ACCESS_KEY_ID', secretkeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    script {
                        bat "terraform apply -auto-approve -var-file=${env.CLEAN_BRANCH}.tfvars"
                        
                        // Extract outputs using PowerShell
                        env.INSTANCE_IP = powershell(script: 'terraform output -raw instance_public_ip', returnStdout: true).trim()
                        env.INSTANCE_ID = powershell(script: 'terraform output -raw instance_id', returnStdout: true).trim()

                        echo "Provisioned IP: ${env.INSTANCE_IP}"
                        bat "echo ${env.INSTANCE_IP} > dynamic_inventory.ini"
                    }
                }
            }
        }

        stage('Wait for AWS Instance Status') {
            steps {
                withCredentials([aws(credentialsId: 'AWS_Aadii', accesskeyVariable: 'AWS_ACCESS_KEY_ID', secretkeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    echo "Waiting for instance ${env.INSTANCE_ID} to pass AWS system health checks..."
                    bat "aws ec2 wait instance-status-ok --instance-ids ${env.INSTANCE_ID} --region ${env.AWS_REGION}"
                }
            }
        }

        stage('Wait for SSH Readiness') {
            steps {
                script {
                    echo "Checking SSH (Port 22) accessibility on ${env.INSTANCE_IP}..."
                    def sshReady = false
                    // Retry loop to account for OS boot time
                    for (int i = 0; i < 12; i++) { 
                        def result = powershell(script: "Test-NetConnection -ComputerName ${env.INSTANCE_IP} -Port 22 -WarningAction SilentlyContinue | Select-Object -ExpandProperty TcpTestSucceeded", returnStdout: true).trim()
                        if (result == "True") {
                            echo "✅ SSH Port is open and reachable."
                            sshReady = true
                            break
                        }
                        echo "⏳ SSH not ready, retrying in 10s... (Attempt ${i+1}/12)"
                        sleep 10
                    }
                    if (!sshReady) {
                        error "❌ SSH service failed to respond on ${env.INSTANCE_IP} after 2 minutes."
                    }
                }
            }
        }

        // --- THIS IS THE SAFETY CHECK FOR ANSIBLE ---
        stage('Validate Ansible') {
            steps {
                script {
                    // This creates a pause in the Jenkins UI. 
                    // You must click "Proceed" to continue to the WSL command.
                    input message: "Infrastructure is healthy and SSH is ready. Run Ansible playbook via WSL?", ok: "Run Ansible"
                }
            }
        }

        stage('Ansible Configuration') {
            steps {
                echo "Running Ansible via WSL Bridge..."
                // WSL command runs non-interactively because we already got approval above
                bat "wsl ansible-playbook -i dynamic_inventory.ini grafana_playbook.yml -u ubuntu --private-key ${env.WSL_SSH_KEY}"
            }
        }

        stage('Ansible Testing') {
            steps {
                echo "Testing Grafana access..."
                bat "wsl ansible-playbook -i dynamic_inventory.ini test_grafana.yml -u ubuntu --private-key ${env.WSL_SSH_KEY}"
            }
        }

        stage('Manual Destroy') {
            steps {
                input message: "Testing finished. Destroy infrastructure for ${env.CLEAN_BRANCH}?", ok: "Destroy Now"
                
                withCredentials([aws(credentialsId: 'AWS_Aadii', accesskeyVariable: 'AWS_ACCESS_KEY_ID', secretkeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    bat "terraform destroy -auto-approve -var-file=${env.CLEAN_BRANCH}.tfvars"
                }
            }
        }
    }

    post {
        always {
            bat 'if exist dynamic_inventory.ini del /f dynamic_inventory.ini'
        }
        success {
            echo "✅ Deployment on branch '${env.CLEAN_BRANCH}' completed successfully!"
        }
        failure {
            script {
                if (env.CLEAN_BRANCH) {
                    withCredentials([aws(credentialsId: 'AWS_Aadii', accesskeyVariable: 'AWS_ACCESS_KEY_ID', secretkeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                        echo "🚨 Pipeline failed. Attempting automated cleanup for ${env.CLEAN_BRANCH}..."
                        bat "terraform destroy -auto-approve -var-file=${env.CLEAN_BRANCH}.tfvars || echo 'Manual cleanup required'"
                    }
                }
            }
        }
    }
}