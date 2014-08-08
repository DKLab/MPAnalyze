function status = outputDialog( this )
%OUTPUTDIALOG A GUI dialog that displays the variables that have been
%returned to an MPBus object and need to be put on a MPWorkspace
%   Detailed explanation goes here

    
    HIGHLIGHT_FORMAT = '<HTML><font color="red">%s</font></HTML>';
    
    workspaceVariableList = this.variables();
    variablesRemaining = this.bufferSize();

    % build a cell array for the uitable
    cellIndex = 1;
    if variablesRemaining > 0
        varData = cell(variablesRemaining, 2);
        while variablesRemaining > 0
            [name, value, variablesRemaining, status] = this.popBuffer();
        
            % dont send varargout to the workspace -- this is a special variable
            % name and usually contains a handle to the GUI that returned it
            if ~strcmp(name, 'varargout') && status
                % if the variable name already exists, highlight it
                if ismember(name, workspaceVariableList)
                    varData{cellIndex, 1} = sprintf(HIGHLIGHT_FORMAT, name);
                else
                    % TODO: DO NOT APPLY FORMAT HERE
                    varData{cellIndex, 1} = sprintf(HIGHLIGHT_FORMAT, name);
                end
                
            varData{cellIndex, 2} = true;
            
            cellIndex = cellIndex + 1;    
                
            end
        end
        
        % only display the GUI if there are variables
        if ~isempty(varData{1,1})
             handles = createGUI(varData);

            guidata(handles.main, handles);

            status = true;

        else
             status = false;
        end
    else
        status = false;
    end
    
    
    
   
end

function cellSelected(hObject, eventdata)

    % remove any HTML from the cell
    handles = guidata(hObject);
    
    varData = 

end

function handles = createGUI(varData)

    handles.main = figure(...
        'Color',[0.941176470588235 0.941176470588235 0.941176470588235],...
        'Colormap',[0 0 0.5625;0 0 0.625;0 0 0.6875;0 0 0.75;0 0 0.8125;0 0 0.875;0 0 0.9375;0 0 1;0 0.0625 1;0 0.125 1;0 0.1875 1;0 0.25 1;0 0.3125 1;0 0.375 1;0 0.4375 1;0 0.5 1;0 0.5625 1;0 0.625 1;0 0.6875 1;0 0.75 1;0 0.8125 1;0 0.875 1;0 0.9375 1;0 1 1;0.0625 1 1;0.125 1 0.9375;0.1875 1 0.875;0.25 1 0.8125;0.3125 1 0.75;0.375 1 0.6875;0.4375 1 0.625;0.5 1 0.5625;0.5625 1 0.5;0.625 1 0.4375;0.6875 1 0.375;0.75 1 0.3125;0.8125 1 0.25;0.875 1 0.1875;0.9375 1 0.125;1 1 0.0625;1 1 0;1 0.9375 0;1 0.875 0;1 0.8125 0;1 0.75 0;1 0.6875 0;1 0.625 0;1 0.5625 0;1 0.5 0;1 0.4375 0;1 0.375 0;1 0.3125 0;1 0.25 0;1 0.1875 0;1 0.125 0;1 0.0625 0;1 0 0;0.9375 0 0;0.875 0 0;0.8125 0 0;0.75 0 0;0.6875 0 0;0.625 0 0;0.5625 0 0],...
        'DockControls','off',...
        'IntegerHandle','off',...
        'MenuBar','none',...
        'Name','Output',...
        'NumberTitle','off',...
        'PaperPosition',get(0,'defaultfigurePaperPosition'),...
        'Position',[544 112 400 300],...
        'HandleVisibility','callback',...
        'UserData',[],...
        'Tag','figure1',...
        'Visible','on' );
    
    handles.label_top = uicontrol(...
        'Parent', handles.main, ...
        'Units', 'normalized', ...
        'Position',  [0.1 0.85 0.8 0.1], ...
        'Style', 'text', ...
        'String', 'A Module has returned the following variables.' );
    
    handles.label_bottom = uicontrol(...
        'Parent', handles.main, ...
        'Units', 'normalized', ...
        'Position',  [0.1 0.25 0.8 0.1], ...
        'Style', 'text', ...
        'String', 'Click on a variable to rename it.' );
    
    
    columnName = {'Variable Name', 'Keep?'};
    columnFormat = {'char', 'logical'}; 
    columnEditable = [true true];
    columnWidth = {250, 50};
    handles.table_variables = uitable(...
        'Parent', handles.main, ...
        'Units', 'normalized', ...
        'Position', [0.1 0.35 0.8 0.5], ...
        'Data', varData, ...
        'ColumnName', columnName, ...
        'ColumnFormat', columnFormat, ...
        'ColumnEditable', columnEditable, ...
        'ColumnWidth', columnWidth, ...
        'RowName', [], ...
        'Tag', 'table_modules', ...
        'CellSelectedCallback', @cellSelected);
    

end