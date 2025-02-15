classdef UnwrappedTSDBNSTS < StateTrackerSearch
% class for implementing network search algorithms that know which
% states need to be re-evalutated and which don't on Two-Stage Dynamic BNs
% Keeps lists of all possible edges and whether or not they are: legal,
% illegal, possible, and need to be reevaluated.
%
% Michael McGeachie (c) 2014. MIT license. See cgbayesnets_license.txt.
    
    properties
    end

    methods
        
        % constructor
        function dbnsts = UnwrappedTSDBNSTS(contData, discData, priorPrecision, ...
                phencol, backtracking, bf_thresh, nophenotype, checkRepeats)
            if (nargin < 5)
                backtracking = false;
            end
            if (nargin < 6)
                bf_thresh = 0;
            end
            if (nargin < 7)
                % change default here for dynamic bayes net:
                nophenotype = true;
            end
            if (nargin < 8)
                checkRepeats = true;
            end
            dbnsts@StateTrackerSearch(contData, discData, priorPrecision, ...
                phencol, backtracking, bf_thresh, nophenotype, checkRepeats);
            dbnsts.cycles = false;
            dbnsts.self = false;
        end

        function obj = SetUnwrappedTimeSeries(obj)
            % call after dbnsts.Init()
        	% this sets up the search to be a dynamic bayesian network for
        	% time series data
            
            % cut off edges from t0 data to t0 data
            % continuous nodes are ordered before discrete nodes
            % and then doubled so we have :
            % [contdata_t0, contdata_tn, discdata_t0, discdata_tn]
            
            % close anything from contdata_t0 to contdata_t0:
            obj.closed(1:(obj.numContNode/2),1:(obj.numContNode/2)) = ones(obj.numContNode/2);
            % close anything from discdata_t0 to discdata_t0:
            obj.closed(obj.numContNode+1:obj.numContNode+(obj.numDiscNode/2), ...
                obj.numContNode+1:obj.numContNode+(obj.numDiscNode/2)) = ...
                ones(obj.numDiscNode/2);
            % now close anything from discdata_tn to contdata_t0:
            obj.closed((obj.numContNode+(obj.numDiscNode/2)+1):end,1:(obj.numContNode/2)) = ...
                ones(obj.numDiscNode/2,obj.numContNode/2);
            % and close anything from discdata_tn to discdata_t0
            obj.closed((obj.numContNode+(obj.numDiscNode/2)+1):end,(obj.numContNode+1):...
                (obj.numContNode+(obj.numDiscNode/2))) = ones(obj.numDiscNode/2);            
            % close anything from contdata_tn to contdata_t0
            obj.closed((obj.numContNode/2)+1:obj.numContNode,1:(obj.numContNode/2)) = ...
                ones(obj.numContNode/2);            
            
            % cut off edges from tn data to t0 data            
            obj.never = obj.closed;
        end


    end
end
