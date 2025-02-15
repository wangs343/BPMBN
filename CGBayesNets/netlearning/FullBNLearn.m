function [BNet, outstats] = FullBNLearn(data, cols, pheno, BFTHRESH, ...
    outfilename, priorPrecision, disc, verbose, searchParameter)
%[BNet,outstats] = FullBNLearn(data, cols, pheno, BFTHRESH, outfilename, ...
%   priorPrecision, disc, verbose, searchParameter)
%
% Learns a CG Bayes Net on the data.  Uses typical bayesian prior values.
% Ouputs to both trivial graph format and SIF format for Cytoscape.  Uses
% exhaustive search to learn the full network; not limited by any K2-style
% order on nodes.
%
% INPUT:
% DATA: data array
% COLS: column names, a cell array of strings
% PHENO: a string representing the phenotype column to predict.  Is matched
%   against the COLS array.
% BFTHRESH: log Bayes Factor threshold for edge inclusion.  Edges below this
%   threshold will not be created.  This is the main stopping criteria.
%   Default = 0.
% OUTFILENAME: filename for output.  Defaults to a file starting with
%   'FullBN_'
% PRIORPRECISION: allows specifying these parameters:
%   priorPrecision.nu; % prior sample size for prior variance estimate
%   priorPrecision.sigma2; % prior variance estimate
%   priorPrecision.alpha; % prior sample size for discrete nodes
%   priorPrecision.maxParents; % hard-limit on the number of parents
%   	each node. optional, will be filled in with default values if omitted.
% DISC: optional.  allows specifying which variables are to be treated as
%   discrete.
% VERBOSE: optional. if true, will output files of each bootstrap network.
%   Default = false.
% SEARCHPARAMETER: allows specifying several optional parameters for
%       network search:
%   searchParameter.backtracking: if true, will use exhaustive search allowing
%       edges to be backed out when that increases the likelihood. Default =
%       false.
%   searchParameter.annealing: if true, will use simulated annealing algorithm for
%       network search.  Default = false.
%   searchParameter.SA_Temp_Mult: if present, will use this as a 
%       multiplier of the usual simulated annealing temperature schedule, 
%       making the search take (SA_Temp_Mult) times as long as normal.
%   searchParameter.Back_Step_Mult: if present, will use this as a 
%       multiplier of the probability of making a backwards move. 
%   searchParameter.DBN: a boolean, if true, indicates that we're learing a
%       two-stage dynamic bayes net, and will use the TSDBNStateTrackerSearch
%       class. Default = false.
%   A dynamic bayes net must further define:
%   searchParameter.d0: earlier time data, output from MakeTSBNData()
%   searchParameter.dn: subsequent time data, output from MakeTSBNData()
%
% OUTPUT:
% BNET: BayesNet class object representing the bayesnet returned.  Will not
%   be a markov-blanket.
% OUTSTATS: structure with fields describing the characteristics of the
%       search procedure, in arrays per "step;" a step is either an edge
%       added or removed.
%   outstats.lldiffs: difference in loglikelihood at each step of the algorithm.
%   outstats.numedges: number of edges in the network at each step of the algorithm.
%   outstats.temp: simulated annealing temperature at each step.
%   outstats.numevals: number of potential network states evaluated at each
%       step.
%
% Copyright Hsun-Hsien Chang, 2010.  MIT license. See cgbayesnets_license.txt.

if (nargin < 4)
    BFTHRESH = 0;
end
if (nargin < 5 || isempty(outfilename))
    outfilename = ['FullBN_', pheno,'_BF', num2str(BFTHRESH)];
end
if (nargin < 6)
    priorPrecision.alpha = 2; %prior frquency for discrete data
    priorPrecision.nu = 2; %prior sample size for continuous data
    priorPrecision.sigma2 = 1; %variance in the prior (hypothetical) samples for continuous data
    priorPrecision.maxParents = 2;
end
if (nargin < 7)
    MAXDISCVALS = 4;
    disc = IsDiscrete(data,MAXDISCVALS);
end
if (nargin < 8)
    verbose = false;
end
if (nargin < 9)
    searchParameter.backtracking = false;
    searchParameter.annealing = false;
else
    if (~isfield(searchParameter,'backtracking'))
        searchParameter.backtracking = false;
    end
    if (~isfield(searchParameter,'annealing'))
        searchParameter.annealing = false;
    end
end
if (~isfield(searchParameter,'DBN'))
    searchParameter.DBN = false;
end



cols_input = cols;

%% pull phenotype out of the dataset
if (isempty(pheno))
    phenname = '';
    phencol = [];
elseif (ischar(pheno))
    phencol = strmatch(pheno, cols, 'exact');
    phenname = pheno;
    pheno = data(:,phencol);
    npind = true(1,length(cols));
    npind(phencol) = false;
    data = data(:,npind);
    cols = cols(npind);
    phendisc = disc(~npind);
    disc = disc(npind);
else
    % phenotype was input as a number, which we treat as an index into the
    % columns
    phenname = 'pheno';
    phendisc = disc(pheno);
    phencol = pheno;
end

%% split data into discrete and continuous parts

ddata = data(:,disc);
dcols = cols(disc);
cdata = data(:,~disc);
ccols = cols(~disc);

%% if two-stage dynamic Bayes Net :
if (isfield(searchParameter,'DBN') && searchParameter.DBN)
    % set other search parameters for using a two-stage dynamic BN
    searchParameter.t0cont = searchParameter.d0(:,~disc)';
    searchParameter.tncont = searchParameter.dn(:,~disc)';
    searchParameter.t0disc = searchParameter.d0(:,disc)';
    searchParameter.tndisc = searchParameter.dn(:,disc)';
    searchParameter.nophenotype = true;
end


%% parameters for Bayes network learning
searchParameter.BF_THRESH=BFTHRESH;
if (isempty(pheno))
    searchParameter.nophenotype = true;
end

%% reshape the data format for network learning
if (~isempty(pheno))
    if (phendisc)
        ddata = [ddata,pheno];
        dcols{end+1} = phenname;
        phencol = length(dcols) + length(ccols);
    else
        cdata = [cdata,pheno];
        ccols{end+1} = phenname;
        phencol = length(ccols);
    end
end

%% learn Bayes network
disp('Start learning Bayesian network!');
if (searchParameter.annealing)
    [BN,outstats]=SimAnnealLearn(cdata',ddata',priorPrecision,phencol,searchParameter); 
else
    [BN,outstats]=ExhaustiveFullNetSearch(cdata',ddata',priorPrecision,phencol,searchParameter); 
    outstats.temp = 0;
end
%note: BayesNet.adjMatrix(m,n)=1 if m is a parent of n
disp('!Done learning Bayesian network!');
nodenames = {ccols{:},dcols{:}};
nodedisc = [false(1,length(ccols)),true(1,length(dcols))];
% change to use BayesNet class
BNet = BayesNet([],outfilename,BN.adjMatrix,BN.weightMatrix,[],false,nodedisc,[cdata,ddata],nodenames,phenname,priorPrecision,{});

%adjmat = BayesNet.adjMatrix;
if (verbose)
    BNet.WriteToTGF();
    BNet.WriteToGML();
end

BNet = BNet.ReorderByNames(cols_input);
