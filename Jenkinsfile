pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key')     // Ensure these are set in Jenkins
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-key')
        TF_VAR_private_key    = '/var/lib/jenkins/my-key.pem'     // Path to your .pem key on Jenkins server
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init & Plan') {
            steps {
                sh 'terraform init'
                sh 'terraform plan -out=tfplan'
            }
        }

        stage('Terraform Apply (Provision Instance)') {
            steps {
                sh 'terraform apply -auto-approve tfplan'
                // Save IP to a file for Ansible to use
                sh 'terraform output -raw instance_ip > instance_ip.txt'
            }
        }

        stage('Wait for Instance Boot') {
            steps {
                sleep 60 // Give EC2 time to initialize SSH
            }
        }

        // --- MANUAL STEP 1: ASK TO RUN ANSIBLE ---
        stage('Approval for Configuration') {
            input {
                message "Instance launched. Do you want to install Grafana via Ansible?"
                ok "Yes, Configure"
            }
            steps {
                echo "Proceeding with Ansible configuration..."
            }
        }

        stage('Run Ansible (Install Grafana)') {
            steps {
                script {
                    def ip = readFile('instance_ip.txt').trim()
                    sh """
                        # Create a temporary inventory file
                        echo "[web]" > inventory
                        echo "${ip} ansible_user=ubuntu ansible_ssh_private_key_file=${env.TF_VAR_private_key} ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> inventory
                        
                        # Run Playbook
                        ansible-playbook -i inventory playbook.yml
                    """
                }
            }
        }

        // --- MANUAL STEP 2: ASK TO DESTROY ---
        stage('Approval for Destroy') {
            input {
                message "Work finished? Do you want to destroy the infrastructure?"
                ok "Yes, Destroy Everything"
            }
            steps {
                echo "Proceeding to destroy infrastructure..."
            }
        }

        stage('Terraform Destroy') {
            steps {
                sh 'terraform destroy -auto-approve'
            }
        }
    }
}