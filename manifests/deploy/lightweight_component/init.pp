 class simple_grid::deploy::lightweight_component::init(
  $execution_id,
  $deploy_status_file = lookup('simple_grid::nodes::lightweight_component::deploy_status_file'),
  $intial_deploy_status = lookup('simple_grid::stage::deploy::status::initial')
){
    #execution happens using puppet apply through the deploy task during the deploy stage   
    notify{"Incoming request for execution id ${execution_id}":} 
    simple_grid::update_execution_request_history($deploy_status_file, $execution_id)
    $execute_now = simple_grid::execute_now($deploy_status_file, $execution_id, $intial_deploy_status)
    notify{"Execute Now? ${execute_now}":}
    if $execute_now {
        # simple_grid::set_execution_status('/etc/simple_grid/.deploy_status.yaml', $execution_id, "deploying")
        class {"simple_grid::components::component_repository::deploy":
            execution_id => $execution_id
        }
    }   
}