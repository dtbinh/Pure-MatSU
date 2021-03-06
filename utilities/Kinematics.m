classdef Kinematics < handle
% KINEMATICS Class to perform kinematics calculations
% Handles force-torque application, derivative calculationa and state integration
%
% Other m-files required: simulation_options, Vehicle, VehicleState
% MAT-files required: none
%
% See also: simulation_options, Vehicle, VehicleState

% Created at 2018/05/10 by George Zogopoulos-Papaliakos
% Last edit at 2018/05/16 by George Zogopoulos-Papaliakos
    
    properties
        vec_force_body; % force vector in body frame
        vec_torque_body; % torque vector in body frame
        dt; % Integration time step
        state; % Internal vehicle state
        vec_pos_dot;
        vec_euler_dot;
        vec_vel_linear_body_dot;
        vec_vel_angular_body_dot;
    end
    
    methods
        
        function obj = Kinematics(sim_options)
            % KINEMATICS Class constructor
            %
            % Syntax:  [obj] = Kinematics(sim_options)
            %
            % Inputs:
            %    sim_options - Struct containing simulation options, output from simulation_options function
            %
            % Outputs:
            %    obj - Class instance
            
            obj.vec_force_body = zeros(3,1);
            obj.vec_torque_body = zeros(3,1);
            obj.state = VehicleState();
            obj.vec_pos_dot = zeros(3,1);
            obj.vec_euler_dot = zeros(3,1);
            obj.vec_vel_linear_body_dot = zeros(3,1);
            obj.vec_vel_angular_body_dot = zeros(3,1);
            obj.dt = sim_options.solver.dt;
            
        end
        
        function set_wrench_body(obj, vec_force_body, vec_torque_body)
            % SET_WRENCH_BODY Set the kinematics force and torque input
            %
            % Syntax:  [] = set_wrench_body(vec_force_body, vec_torque_body)
            %
            % Inputs:
            %    vec_force_body - A 3x1 vector, containing the force applied on the vehicle, in body-frame (in SI units)
            %    vec_torque_body - A 3x1 vector, containing the torque applied on the vehicle, in body-frame (in SI units)
            %
            % Outputs:
            %    (none)
           
            obj.vec_force_body = vec_force_body;
            obj.vec_torque_body = vec_torque_body;
            
        end
        
        function calc_state_derivatives(obj, vehicle)
            % CALC_STATE_DERIVATIVES Calculate the state derivatives
            % Requires a vehicle instance to acquire inertial parameters. Performs point-mass, rigid-body kinematics.
            %
            % Syntax:  [] = calc_state_derivatives(vehicle)
            %
            % Inputs:
            %    vehicle - A Vehicle instance
            %
            % Outputs:
            %    (none)
            
            % Setup the matrix of inertia
            J = zeros(3,3);
            J(1,1) = vehicle.inertial.j_x;
            J(2,2) = vehicle.inertial.j_y;
            J(3,3) = vehicle.inertial.j_z;
            J(1,3) = -vehicle.inertial.j_xz;
            J(3,1) = -vehicle.inertial.j_xz;
            % Calcualte its inverse
            J_i = J^(-1);
            
            % Read rotation matrix
            R_be = vehicle.R_be();
            
            % Calculate position derivative
            vec_vel_linear_body_prev = obj.state.get_vec_vel_linear_body();
            obj.vec_pos_dot = R_be*vec_vel_linear_body_prev;
            
            % Calculate velocity derivative
            vec_vel_angular_body_prev = obj.state.get_vec_vel_angular_body();
            vec_euler_prev = obj.state.get_vec_euler();
            phi = vec_euler_prev(1);
            theta = vec_euler_prev(2);
            psi = vec_euler_prev(3);
            E = [1 tan(theta)*sin(phi) tan(theta)*cos(phi);...
                0 cos(phi) -sin(phi);...
                0 sin(phi)/cos(theta) cos(phi)/cos(theta)];
            obj.vec_euler_dot = E*vec_vel_angular_body_prev;
            
            % Calculate linear velocity derivatives
            linear_acc = obj.vec_force_body/vehicle.inertial.mass;
            corriolis_acc = -cross(vec_vel_angular_body_prev, vec_vel_linear_body_prev);
            obj.vec_vel_linear_body_dot = linear_acc + corriolis_acc;
            
            % Calculate angular velocity derivatives
            obj.vec_vel_angular_body_dot = J_i*(obj.vec_torque_body - cross(vec_vel_angular_body_prev, (J*vec_vel_angular_body_prev)));
            
        end
        
        function answer = get_state_derivatives(obj)
            % GET_STATE_DERIVATIVES Accessor for the internal state derivatives members
            % Return the internal state derivatives as a structure
            %
            % Syntax:  [answer] = get_state_derivatives()
            %
            % Inputs:
            %    (none)
            %
            % Outputs:
            %    answer - a struct with members: vec_pos_dot, vec_euler_dot, vec_vel_linear_body_dot,
            %    vec_vel_angular_body_dot (in SI units)
            
            answer.vec_pos_dot = obj.vec_pos_dot;
            answer.vec_euler_dot = obj.vec_euler_dot;
            answer.vec_vel_linear_body_dot = obj.vec_vel_linear_body_dot;
            answer.vec_vel_angular_body_dot = obj.vec_vel_angular_body_dot;            
            
        end
        
        function answer = get_state_derivatives_serial(obj)
            % GET_STATE_DERIVATIVES_SERIAL Accessor for the internal state derivatives members
            % Return the internal state derivatives as a vertical vector
            %
            % Syntax:  [answer] = get_state_derivatives_serial()
            %
            % Inputs:
            %    (none)
            %
            % Outputs:
            %    answer - a 12x1 vector with contents: 3x1 position derivative, 3x1 Euler angle derivatives, 3x1 linear
            %    velocity derivatives, 3x1 angular velocity derivatives
            
            answer = [...
                obj.vec_pos_dot;...
                obj.vec_euler_dot;...
                obj.vec_vel_linear_body_dot;...
                obj.vec_vel_angular_body_dot...
                ];            
            
        end
        
        function integrate_fe(obj)  
            % INTEGRATE Integrate internal state using the internal state derivatives, for one time step
            % Uses Forward-Euler integration
            %
            % Syntax:  [] = integrate()
            %
            % Inputs:
            %    (none)
            %
            % Outputs:
            %    (none)         
            
            obj.state.set_vec_pos(obj.state.get_vec_pos() + obj.vec_pos_dot*obj.dt);
            obj.state.set_vec_euler(obj.state.get_vec_euler() + obj.vec_euler_dot*obj.dt);
            obj.state.set_vec_vel_linear_body(obj.state.get_vec_vel_linear_body() + obj.vec_vel_linear_body_dot*obj.dt);
            obj.state.set_vec_vel_angular_body(obj.state.get_vec_vel_angular_body() + obj.vec_vel_angular_body_dot*obj.dt);
            
        end
        
        function set_state(obj, external_state)
            % SET_STATE Setter method for the internal vehicle state
            %
            % Syntax:  [] = set_state(external_state)
            %
            % Inputs:
            %    external_state - A VehicleState instance
            %
            % Outputs:
            %    (none)  
            
            obj.state.set_state(external_state);
            
        end
        
        function state = get_state(obj)
            % SET_STATE Getter method for the internal vehicle state
            %
            % Syntax:  [state] = get_state()
            %
            % Inputs:
            %    (none)
            %
            % Outputs:
            %    external_state - A VehicleState instance
           
            state = VehicleState();
            state.set_state(obj.state);
            
        end
        
        function write_state(obj, external_state)
            % WRITE_STATE Copy the internal state to an externally passed vehicle state
            % Acquires the external state (a VehicleState instance) by reference
            %
            % Syntax:  [] = write_state(external_state)
            %
            % Inputs:
            %    external_state - A VehicleState instance
            %
            % Outputs:
            %    (none)
            
            external_state.set_vec_pos(obj.state.get_vec_pos());
            external_state.set_vec_euler(obj.state.get_vec_euler());
            external_state.set_vec_vel_linear_body(obj.state.get_vec_vel_linear_body());
            external_state.set_vec_vel_angular_body(obj.state.get_vec_vel_angular_body());   
            
        end
        
    end
    
end

