classdef MPBus < handle
    properties(Constant = true)
        MODULE_FILE = 'modules.mat';
        DISPATCH_FILE = 'dispatches.mat';
        ROOT_FOLDER = 'MPAnalyze';
    end
    
    properties
        verbose;        % when true, member functions will display info and
                        % error messages to the command window.
                        
        guiHandle;      % a handle to the master GUI
        
        fullFileName;   % name of the current hdf5 file
        activeChannel;  % the channel that is currently being analyzed
        channelList;    % the list of channels available in the
                        % current hdf5 file
        analogChannelList;  % same as channelList but for the analog (stim) channels
        
        numFrames;      % total number of frames in a dataset
        xsize;          % frame width
        ysize;          % frame height
        
        header;         % a struct containing the /Config attributes
                        % from the current hdf5 file
        scanData;       % a struct containing the /ArbScanPath attributes
                        % from the current hdf5 file
                        
        history;        % struct array that indicates what operations have 
                        % been done on the data so far.
                        % the struct will have the following fields:
                        %       name of the operation
                        %       m file for the operation
                        %       date/time stamp
                        
        fid;            % current file ID
        gid;            % current group ID  FIXME: MAY NOT NEED THIS
        
        buffer;         % temporarily stores output from modules
        
        modules;        % modules is a list of all registered modules that  
                        % MPBus can run. A module can be a function or a GUI.
        
        workspace;      % the MPWorkspace object attached to this MPBus
        workspaceIsBase;    % should the workspace be exported to the base workspace
                            % when new variables are added?
        
        root;           % the folder path of the function that created this
                        % MPBus object.

    end
    
    methods
        %------------------------------------------------------------------
        % API methods
  
        [variableNameList, status] = variables(this);
        
        % output() sends a variable to the buffer (output from module) 
        status = output(this, variableName, variableValue, moduleName);
        % input() gets a variable from the workspace (input to module)
        [variableValue, status] = input(this, variableName);
        % gui() creates a gui to gather user input
        [populatedParameterStruct, status] = gui(this, parameterStruct, labelStruct);
        
        
        %------------------------------------------------------------------
        % HDF5 methods
        status = open(this, fullFileName);
        data = readHeader(this, groupName);
        data = readLines(this, lineRange);
        data = readAnalog(this, channel, frameRange);
        data = readScanData(this);      
        channels_vector = getImageChannels(this);
        
        %------------------------------------------------------------------
        % logistics
        
        status = populateModuleList(this);
        status = runModule(this, moduleName);
        status = registerModule(this, moduleName, functionPath, ...
                                functionName, isGUIflag);
        module = getModule(this, moduleName);
        mpdispatch = makeDispatch(this, moduleName);
        
        status = pushBuffer(this, variableName, variableValue);
        [variableName, variableValue, newBufferSize, status] = popBuffer(this);
        nVariables = bufferSize(this);
        
        % the GUI to allow users to accept variables from the buffer and
        % place on the MPWorkspace
        status = outputDialog(this);
        
        %status = registerRefreshFunction(this, functionHandle);
        %status = dispatchRefresh(this);
        
        %------------------------------------------------------------------
        % constructor
        function this = MPBus(GUI_Handle, useBaseWorkspace)
            % the GUI that created this MPBus object is in the root
            % directory. Use this opertunity to determine the root
            % directory and make the information globally available.
            % (global because functions that have no access to a MPBus will
            % still need this information, and its not static or constant)
            global MPBusRoot;
            fullpath = mfilename('fullpath');
            sliceIndex = regexp(fullpath, '@MPBus');
            MPBusRoot = fullpath( 1 : sliceIndex - 1 );
            
            
            if ~nargin
                % no GUI handle was passed in
                % at this point I'm not sure if anything should
                % be done about that
                GUI_Handle = [];
                useBaseWorkspace = true;
            end
            
            this.workspace = MPWorkspace();
            this.guiHandle = GUI_Handle;
            
            if ~exist('useBaseWorkspace', 'var')
                useBaseWorkspace = true;
            end
            
            this.workspaceIsBase = useBaseWorkspace;
            
            % build a list of modules that can be run
            this.populateModuleList();
        end
        
        %------------------------------------------------------------------
        % destructor
        function delete(this)
            % close any open hdf5 files and groups
            try
                H5G.close(this.gid);
                H5F.close(this.fid);
            catch
                % no need to treat this as an error -- it just means that
                % fid or gid wasn't open anyway.
            end
            
            % save the registered modules list to a .mat file to be loaded
            % again when a new MPBus object is created.
            
        end
        
        %------------------------------------------------------------------
        % display exception messages
        function dispException(this, exception)
            if this.verbose
                disp('--------------------------------------');
                disp(exception.identifier);
                disp(exception.message);
                disp('--------------------------------------');
            end    
        end
        
        %------------------------------------------------------------------
        % get and set functions
        function filename = getFilename(this)
            [~,name,ext] = fileparts(this.fullFileName);
            filename = [name ext];
        end
        
    end
    
    methods(Static = true)
        %------------------------------------------------------------------
        % static methods
        
        [inputs, outputs] = readSignature(filepath, filename);
        verified = verifyFile(fullFileName, extension);
        
    end
    
end

