#!/opt/puppetlabs/puppet/bin/ruby
require 'open3'
require 'yaml'
require_relative "../../ruby_task_helper/files/task_helper.rb"

class RollbackDeployMaster < TaskHelper
    def process_deploy_status(execution_status_file)
        copy_data = false
        data = File.read(execution_status_file)
        yaml_data = Array.new
        data.each_line do |line|
            if copy_data
                yaml_data << line
            end
            if line.include? "---"
                copy_data = true
            end
        end
        yaml_data = yaml_data[0,yaml_data.length - 4]
        File.open(execution_status_file + ".yaml", 'w') do |file|
            file.puts yaml_data
        end
        deploy_status = YAML.load_file(execution_status_file + ".yaml")
        return deploy_status
    end
    def task(simple_config_dir:nil, augmented_site_level_config_file:nil, deploy_status_file:nil, deploy_status_output_dir:nil, deploy_status_pending:nil, modulepath:nil, **kwargs )
        _overall_deployment_status_file_name = simple_config_dir + "/deployment_output.yaml"
        _data = YAML.load_file(augmented_site_level_config_file)
        _lightweight_components = _data['lightweight_components']
        _output = Array.new
        _lightweight_components.each do |_lightweight_component, index|
            _execution_id = _lightweight_component['execution_id']
            _name = _lightweight_component['name']
            _node_fqdn = _lightweight_component['deploy']['node']
            _deploy_status_output_file = "#{deploy_status_output_dir}/.#{_execution_id}.status" 
            deploy_command = "bolt task run simple_grid::rollback_deploy "\
            " execution_id=#{_execution_id}"\
            " deploy_status_file=#{deploy_status_file}"\
            " --modulepath #{modulepath}"\
            " --nodes #{_node_fqdn}"
            puts deploy_command
            deploy_status_command = "bolt task run simple_grid::deploy_status \
                deploy_status_file=#{deploy_status_file} \
                execution_id=#{_execution_id} \
                --modulepath #{modulepath} \
                --nodes #{_node_fqdn} \
                > #{_deploy_status_output_file}"
            
            puts "Rolling back deployment of #{_name} on #{_node_fqdn} with execution_id = #{_execution_id}"
            deploy_stdout, deploy_stderr, deploy_status = Open3.capture3(deploy_command)  
            
            puts "Fetching deployment status for #{_name} on #{_node_fqdn} with execution_id = #{_execution_id}"
            deploy_status_stdout, deploy_status_stderr, deploy_status_status = Open3.capture3(deploy_status_command)
            deploy_status = process_deploy_status(_deploy_status_output_file)
            if deploy_status['status'] != deploy_status_pending
                puts "Execution of #{_execution_id} failed. Check output available at #{_deploy_status_output_file} for details."
                puts "Latest log entry for Puppet Agent on #{_node_fqdn} was: #{deploy_status['logs'].last}"
                break
            end
            _current_output = {
                "execution_id" => _execution_id,
                "component" => _name,
                "node" => _node_fqdn,
                "status" => deploy_status['status'],
                "log_file" => _deploy_status_output_file
            }
            _output << _current_output
        end
        #delete overall deployment file
        File.delete(_overall_deployment_status_file_name) if File.exists?(_overall_deployment_status_file_name)
        _output.to_yaml
    end
end

if __FILE__ == $0
    RollbackDeployMaster.run
end