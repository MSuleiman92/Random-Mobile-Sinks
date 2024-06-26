function [SN, round_params, stability_period_check, lifetime_check] = round_params_update(SN, round_params, dims, ms_ids, round, rounds, stability_period_check, lifetime_check, mob_params, sn_select_method, pn_select_method)
%ROUND_PARAMS_UPDATE Update the Simulation Parameters during a round
%   This function is used to update all the parameters used in  gathering
%   data for the analytics of the wireless network sensor (WSN).
%
%   INPUT PARAMETERS
%   SN - all sensors nodes (including routing routes)
%   CLheads - number of cluster heads elected.
%   round_params - container of the parameters used to measure the
%                   performance of the simulation in a round. The params
%                   are: 'dead nodes', 'operating nodes', 'total energy', 
%                   'packets', 'stability period', 'lifetime', 
%                   'stability period round', 'lifetime round'.
%   rn_ids - ids of all sensor nodes used for routing
%   round - the current round in the simulation.
%   rounds - the total number of rounds in the simualtion.
%   stability_period_check - boolean indicating the active search of the
%                               stability period metric.
%   lifetime_check - boolean indication the active search of the lifetime
%                       period metric.
%
%   OUTPUT PARAMETERS
%   round_params - container of the parameters used to measure the
%                   performance of the simulation in a round. The params
%                   are: 'dead nodes', 'operating nodes', 'total energy', 
%                   'packets', 'stability period', 'lifetime', 
%                   'stability period round', 'lifetime round'.
%   stability_period_check - boolean indicating the active search of the
%                               stability period metric.
%   lifetime_check - boolean indication the active search of the lifetime
%                       period metric.

if stability_period_check
    if round_params('operating nodes') < length(SN.n) - length(ms_ids)
        round_params('stability period') = toc;
        round_params('stability period round') = round;
        stability_period_check = false;
    elseif round == rounds
        round_params('stability period') = toc;
        round_params('stability period round') = round;
    end
end

if lifetime_check
    if round_params('operating nodes') == length(ms_ids)
        round_params('lifetime') = toc;
        round_params('lifetime round') = round;
        lifetime_check = false;
    elseif round == rounds
        round_params('lifetime') = toc;
        round_params('lifetime round') = round;
    end
end

% Update the amount of visitation by the mobile sinks by proximity to the
% sink nodes
if strcmp(pn_select_method, "no_of_visit")
    ids_visited = [];
    for i = 1:length(SN.n)
        if (strcmp(SN.n(i).role, 'N') || strcmp(SN.n(i).role, 'P')) && strcmp(SN.n(i).cond, 'A')

            dist_to_sinks = zeros(1, length(ms_ids));
            for j = 1:length(ms_ids)
                dist_to_sinks(j) = sqrt( (SN.n(ms_ids(j)).x - SN.n(i).x)^2 + (SN.n(ms_ids(j)).y - SN.n(i).y)^2 );
            end

            dns = min(dist_to_sinks(:)); % Distance to closest mobile sink

            if dns <= mob_params('min_visit_dist')
               SN.n(i).sn_visits = SN.n(i).sn_visits + 1;
               ids_visited(end+1) = i;
            end
        end
    end


    % Update the amount of visitation by the mobile sinks by clusters
    clusters = unique([SN.n.cluster]);

    for cluster = clusters(~isnan(clusters))
        node_ids = []; % Node ID
        min_dists_to_sinks = []; % A nodes shortest distance to a predicted path

        for i=1:length(SN.n)
            if (strcmp(SN.n(i).role, 'N') || strcmp(SN.n(i).role, 'P')) && strcmp(SN.n(i).cond, 'A') && (SN.n(i).cluster == cluster) && (~isnan(cluster))
                node_ids(end+1) = SN.n(i).id;

                dist_to_sinks = zeros(1, length(ms_ids));
                for j = 1:length(ms_ids)
                    dist_to_sinks(j) = sqrt( (SN.n(i).x - SN.n(ms_ids(j)).x)^2 + (SN.n(i).y - SN.n(ms_ids(j)).y)^2 );
                end

                min_dists_to_sinks(end+1) = min(dist_to_sinks(:));
            end 
        end

        [~, J] = max(min_dists_to_sinks(:)); % finds the maximum visits of node by MS

        node_id = node_ids(J);
        if ~ismember(node_id, ids_visited)
            SN.n(node_id).sn_visits = SN.n(node_id).sn_visits + 1;
        end
    end
end

for i = 1:length(SN.n)
    
    % Storing on the round positions and the positional attributes
    SN.n(i).Xs(round) = SN.n(i).x;
    SN.n(i).Ys(round) = SN.n(i).y;
    SN.n(i).ALPHAs(round) = SN.n(i).alpha;
    SN.n(i).COLs(round) = SN.n(i).col;
    
    if strcmp(sn_select_method, "RMMS") && strcmp(pn_select_method, "cluster_head")
        continue
    end
    
    % Update new node positions
    if (strcmp(SN.n(i).role, 'N') || strcmp(SN.n(i).role, 'P')) && strcmp(SN.n(i).cond, 'A')
        dist_moved = mob_params('min_dist') + rand * (mob_params('max_dist') - mob_params('min_dist'));
    elseif strcmp(SN.n(i).role, 'S')
        dist_moved = mob_params('sn_min_dist') + rand * (mob_params('sn_max_dist') - mob_params('sn_min_dist'));
    else
        dist_moved =0;
    end
    
    direction_moved = -180 + rand * 360;

    if (dist_moved ~= 0)
        mobility_complete = false;
        while (~mobility_complete)
            if ( strcmp(SN.n(i).role, 'N') || strcmp(SN.n(i).role, 'P') )
                x_dest = SN.n(i).x + dist_moved*cosd(direction_moved);
                y_dest = SN.n(i).y + dist_moved*sind(direction_moved);
            elseif ( strcmp(SN.n(i).role, 'S') && (strcmp(sn_select_method, 'RMMS') || strcmp(sn_select_method, 'MRMS-NC')) )
                x_dest = SN.n(i).x + dist_moved*cosd(direction_moved);
                y_dest = SN.n(i).y + dist_moved*sind(direction_moved);
            elseif ( strcmp(SN.n(i).role, 'S') && strcmp(sn_select_method, 'MRMS-C') )
                
                clust_angle = 2*pi/length(ms_ids);

                pos = 0;
                while pos ~= find(ms_ids==i)
                    x_dest = SN.n(i).x + dist_moved*cosd(direction_moved);
                    y_dest = SN.n(i).y + dist_moved*sind(direction_moved);

                    x_rel = x_dest - dims('x_max')/2;
                    y_rel = y_dest - dims('y_max')/2;

                    if x_rel >= 0 && y_rel >= 0
                       reg = atan(x_rel/y_rel)/clust_angle;
                    elseif x_rel < 0
                       reg = ( atan(x_rel/y_rel) + pi )/clust_angle;
                    elseif x_rel >= 0 && y_rel < 0
                       reg = ( atan(x_rel/y_rel) + 2*pi )/clust_angle;
                    end
                    pos = ceil(reg);
                    direction_moved = direction_moved + (0.05*180/pi);
                end
            end
            
            node_moved_out = false;
            
            if x_dest > dims('x_max')
                node_moved_out = true;
                new_direction = 180 - direction_moved;
                x_dest = dims('x_max');
                y_dest = SN.n(i).y + diff([SN.n(i).x x_dest])*tand(direction_moved);  
            end
            if x_dest < dims('x_min')
                node_moved_out = true;
                new_direction = 180 - direction_moved;
                x_dest = dims('x_min');
                y_dest = SN.n(i).y + diff([SN.n(i).x x_dest])*tand(direction_moved);
            end
            if y_dest > dims('y_max')
                node_moved_out = true;
                new_direction = -direction_moved;
                y_dest = dims('y_max');
                x_dest = SN.n(i).x + diff([SN.n(i).y y_dest])/tand(direction_moved); 
            end
            if y_dest < dims('y_min')
                node_moved_out = true;
                new_direction = -direction_moved;
                y_dest = dims('y_min');
                x_dest = SN.n(i).x + diff([SN.n(i).y y_dest])/tand(direction_moved);
            end
            
            SN.n(i).x = x_dest;
            SN.n(i).y = y_dest;

            if node_moved_out
                direction_moved = new_direction;
            else
                mobility_complete = true;
            end
        end
    end
end



end

