function varargout = MPAnalyze(varargin)
% MPANALYZE MATLAB code for MPAnalyze.fig
%      MPANALYZE, by itself, creates a new MPANALYZE or raises the existing
%      singleton*.
%
%      H = MPANALYZE returns the handle to a new MPANALYZE or the handle to
%      the existing singleton*.
%
%      MPANALYZE('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MPANALYZE.M with the given input arguments.
%
%      MPANALYZE('Property','Value',...) creates a new MPANALYZE or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before MPAnalyze_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to MPAnalyze_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help MPAnalyze

% Last Modified by GUIDE v2.5 07-Aug-2014 14:54:12

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @MPAnalyze_OpeningFcn, ...
                   'gui_OutputFcn',  @MPAnalyze_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT



% --- Executes just before MPAnalyze is made visible.
function MPAnalyze_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to MPAnalyze (see VARARGIN)

% Choose default command line output for MPAnalyze
handles.output = hObject;
resetPWD;
%%%%%%%%%%%%%%%%%%
handles.mpbus = MPBus(hObject, false);
handles.INSTALL_STRING = '<HTML><i>Install Module...</i></HTML>';
refreshModules(hObject, handles);
%%%%%%%%%%%%%%%%%%



% UIWAIT makes MPAnalyze wait for user response (see UIRESUME)
% uiwait(handles.figure1);


function resetPWD()
% the present working directory MUST be the same as where this m file is
% located to ensure that MPDispatch will work properly.
fullFileName = [ mfilename('fullpath') '.m' ];
[ desiredPath, ~, ~ ] = fileparts(fullFileName);
cd(desiredPath);


% --- Outputs from this function are returned to the command line.
function varargout = MPAnalyze_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on selection change in popup_moduleName.
function popup_moduleName_Callback(hObject, eventdata, handles)
% hObject    handle to popup_moduleName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popup_moduleName contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popup_moduleName

moduleNameList = cellstr(get(hObject, 'String'));
moduleName = moduleNameList{get(hObject, 'Value')};

% if the module name is 'Install...' then run the registerMod function
% instead
if strcmp(moduleName, handles.INSTALL_STRING)
    registerMod_Callback(handles);
    return;
end

% before making the dispatch, ensure that the present working directory is
% the MPAnalyze root directory
resetPWD();

handles.currentDispatch = handles.mpbus.makeDispatch(moduleName);

guidata(handles.output, handles);
populateArgumentListbox(hObject, handles);
refreshModuleNameText(hObject, handles);

% --- Executes during object creation, after setting all properties.
function popup_moduleName_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popup_moduleName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes on selection change in listbox_arguments.
function listbox_arguments_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_arguments (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_arguments contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_arguments

refreshArgName('', handles);


% --- Executes during object creation, after setting all properties.
function listbox_arguments_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_arguments (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%populateArgumentListbox(hObject, handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function refreshArgName(~, handles)
edit_argName = findall(handles.output, 'tag', 'edit_argName');
listbox_arguments = findall(handles.output, 'tag', 'listbox_arguments');
selectedIndex = get(listbox_arguments, 'Value');

popup_workspaceVariable = findall(handles.output, ...
                                    'tag', 'popup_workspaceVariable');

% update the edit_argName box with the argument name
[~, signatureList] = handles.currentDispatch.getInputList();

argumentName = signatureList{selectedIndex};

set(edit_argName, 'String', argumentName);

% special case -- if the argument is varargin then the user doesn't have a
% choice as to which variable gets passed in (it will automatically be the
% MPBus) so disable the workspace variable popup
if strcmp(argumentName, 'varargin')
    set(popup_workspaceVariable, 'Enable', 'off');
    set(edit_argName, 'Enable', 'off');
else
    set(popup_workspaceVariable, 'Enable', 'on');
    set(edit_argName, 'Enable', 'inactive');
end

%%%%%%%%%%
function populateArgumentListbox(~, handles, returnFocusToIndex)

if ~exist('returnFocusToIndex', 'var')
    returnFocusToIndex = 1;
end

listbox_arguments = findall(handles.output, 'tag', 'listbox_arguments'); 

[workspaceList, signatureList] = handles.currentDispatch.getInputList();

argList = cell(length(signatureList), 1);
argFormat = '%30s  -->  %-20s';

greyOutIndex = [];

for index = 1 : length(signatureList)
    % if varargin is in the signature, this is likely a GUI -- pass the
    % current mpbus as varargin
    if strcmp(signatureList{index}, 'varargin')
        handles.currentDispatch.setInputByIndex('MPBus', index);
        workspaceList{index} = 'MPBus';
        greyOutIndex = index;
    end
    
    argList{index} = sprintf(argFormat, ...
                                workspaceList{index}, signatureList{index});      
end

% convert strings to HTML
for idx = 1 : length(argList)
    argList{idx} = strrep(argList{idx}, ' ', '&nbsp;');
    if idx == greyOutIndex
         argList{idx} = ...
             ['<HTML><Font size=3 color="#404040"><i>' argList{idx} '</i></font></HTML>'];
    else
        argList{idx} = ...
            ['<HTML><Font size=3 color="black">' argList{idx} '</font></HTML>']; 
    end
end


set(listbox_arguments, 'Value', returnFocusToIndex);
refreshArgName('', handles);
set(listbox_arguments, 'String', argList);

%%%%%%%%
function registerMod_Callback(handles)

% get info from the registerMod GUI
[moduleName, functionPath, functionName, parameters] = registerMod();


% module name will be empty if the registerMod GUI was canceled
if ~strcmp(moduleName, '')
    if ~handles.mpbus.registerModule(moduleName, functionPath, functionName, parameters);
        % registerModule returned a status of false -- unable to register
        % module. Check if user wants to try again
        choice = questdlg(sprintf('There was a problem registering the module %s. Try again?\n', ...
                                  moduleName), 'Register Module', 'Yes', 'No', 'Yes');

       if strcmp(choice, 'Yes')
           % user wants to try again, just call this function again
           registerMod_Callback(handles);
       end
    else
        msgbox(sprintf('Module "%s" installed successfully.', moduleName), 'Install Module', 'modal');
        
        % refresh the menu bar
        refreshModules(handles.output, handles);
    end
end

function refreshModules(hObject, handles)
% this function should be run when the GUI first starts up and any time a
% new module is installed
createMenuBar(hObject, handles);



if isempty(handles.mpbus.modules)
    % no modules loaded, the user must install a module or the GUI will
    % exit
    registerMod_Callback(handles);
    handles = guidata(hObject);
    
    if isempty(handles.mpbus.modules)
        fprintf('\nstill empty\n');
        close(handles.output);
        return;
    end
end

% update the modules menu box as well
moduleNameList = { handles.mpbus.modules.moduleName };

popup_moduleName = findall(handles.output, 'tag', 'popup_moduleName');

% make sure that 'Install...' is the last option in the module popup
% control
moduleNameList{end + 1} = handles.INSTALL_STRING;
set(popup_moduleName, 'Value', 1);
set(popup_moduleName, 'String', moduleNameList);

% the previous lines selected the first module in the list as the current
% module
% create a new dispatch for the currently selected module
handles.currentDispatch = handles.mpbus.makeDispatch(moduleNameList{1});
guidata(handles.output, handles);

populateArgumentListbox(hObject, handles);
refreshModuleNameText(hObject, handles);


function refreshModuleNameText(~, handles)
text_moduleName = findall(handles.output, 'tag', 'text_moduleName');
popup_moduleName = findall(handles.output, 'tag', 'popup_moduleName');

moduleNameList = cellstr(get(popup_moduleName, 'String'));
moduleName = moduleNameList{get(popup_moduleName, 'Value')};

set(text_moduleName, 'String', moduleName);



%%%%%%%%%%%%%%%%% MENU BAR %%%%%%%%%%%%%%%%%%%%
function createMenuBar(hObject, handles)

% REMOVING THE MENU BAR FOR NOW
%{
% first, delete all the root menus (this will also delete their children)
old_File = findall(hObject, 'tag', 'menu_File');
old_Module = findall(hObject, 'tag', 'menu_Modules');
delete(old_File);
delete(old_Module);

% then rebuild them
menu = struct();
% top level menus
menu.file = uimenu(hObject, ...
                   'Label', 'File', ...
                   'tag', 'menu_File');
menu.modules = uimenu(hObject, ...
                      'Label', 'Modules', ...
                      'tag', 'menu_Modules');

% file menu
menu.file_open = uimenu(menu.file, 'Label', 'Open...');

% modules menu
menu.modules_install = uimenu(menu.modules, ...
                              'Label', 'Install...', ...
                              'Callback', @menu_Install_Callback);

                          
% populate modules menu
menu.modules_list = [];
for mod_info = handles.mpbus.modules
    menu.modules_list(end + 1) = uimenu(menu.modules, ...
                              'Label', mod_info.moduleName, ...
                              'Callback', @menu_module_Callback);
end

handles.menu = menu;
guidata(hObject, handles);
%}

function importWorkspace(hObject, handles)
% get a list of all variables on the base workspace and let the user select
% which ones to import
workspaceVariables = evalin('base','who');

if isempty(workspaceVariables)
    disp('empty');
    return;
end

[importIndices, status] = listdlg('ListString', workspaceVariables, ...
                                  'PromptString', 'Select workspace variables to import.');

if status
    % put these variables on the mpbus object
    handles.mpbus.workspace.import(workspaceVariables(importIndices));
end


refreshWorkspace(hObject, handles)



function refreshWorkspace(~, handles)
% put the names of all the variables in the workspace listbox

% the workspace listbox is replaced by the workspace table
%listbox_workspace = findall(handles.output, 'tag', 'listbox_workspace');
table_workspace = findall(handles.output, 'tag', 'table_workspace');
popup_workspaceVariable = findall(handles.output, 'tag', 'popup_workspaceVariable');


variableList = handles.mpbus.workspace.variableList;

% the first item in the popup list is 'Choose...'
variablePopupList = cell(length(variableList) + 1, 1);
variableTableList = cell(length(variableList), 3);

variablePopupList{1} = 'Choose...';
for index = 1 : length(variableList);
    variablePopupList{index + 1} = sprintf( ...
        '<HTML><img src="%s"></img><font size=3>%s</font></HTML>', ...
        variableList(index).image, variableList(index).name);
    
    variableValue = variableList(index).value;
    variableSize = size(variableValue);
    sizeString = sprintf('<HTML><font color="#0066CC"><i>%dx%d</i></font></HTML>', ...
                         variableSize(1), variableSize(2));

    try
        variableMin = min(variableValue);
        variableMax = max(variableValue);
    catch
        variableMin = [];
        variableMax = [];
    end
    
    variableTableList{index, 1} = variablePopupList{index + 1};
    variableTableList{index, 2} = sizeString;
    variableTableList{index, 3} = variableMin;
    variableTableList{index, 4} = variableMax;
    

end

% make sure the variableDisplayList isn't empty -- the controls won't
% display properly if it is
if isempty(variablePopupList)
    variablePopupList = {'Choose...'};
end

set(table_workspace, 'Data', variableTableList); 

%set(listbox_workspace, 'Value', 1);
%set(listbox_workspace, 'String', variablePopupList);

set(popup_workspaceVariable, 'Value', 1);
set(popup_workspaceVariable, 'String', variablePopupList);

%%%%%%%%%% UNDOCUMENTED MATLAB %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
uitablepeer = findjobj(handles.output, '-nomenu', 'class', 'uitablepeer');
set(uitablepeer,'MouseClickedCallback', ...
                    {@table_workspace_DoubleClickCallback, handles});
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



function updateDispatch(hObject, handles)
% update the current dispatch with the new association

popup_workspaceVariable = findobj(handles.output, ...
                                  'tag', 'popup_workspaceVariable');
listbox_arguments = findall(handles.output, ...
                                  'tag', 'listbox_arguments');
                              
argIndex = get(listbox_arguments, 'Value');
% also find the next argument index
if size(get(listbox_arguments, 'String'), 1) > argIndex
    nextArgIndex = argIndex + 1;
else
    nextArgIndex = 1;
end
    
workspaceVarList = fieldnames(handles.mpbus.workspace.getVariables());

if iscell(workspaceVarList)
    % the first entry in this popup is not actually a workspace variable
    correctedIndex = get(popup_workspaceVariable, 'Value') - 1;
    % so if the first item was selected, then the user didn't actually
    % choose a workspace variable -- just return
    if correctedIndex < 1
        return;
    end
    
    workspaceVar = workspaceVarList{correctedIndex};

    handles.currentDispatch.setInputByIndex(workspaceVar, argIndex);

    % save the newly updated handles struct
    guidata(handles.output, handles);
    populateArgumentListbox(hObject, handles, nextArgIndex);
end

function popEntireBuffer(hObject, handles)
% pop all variables off the mpbus buffer and resolve any name conflicts

%TODO: NEW: MPBus will handle this
%success = handles.mpbus.outputDialog();

%TODO: old code below:
variablesRemaining = handles.mpbus.bufferSize();

if variablesRemaining > 0
    while variablesRemaining > 0
        [name, value, variablesRemaining, status] = handles.mpbus.popBuffer();

        % dont send varargout to the workspace -- this is a special variable
        % name and usually contains a handle to the GUI that returned it
        if ~strcmp(name, 'varargout') && status
            % alert user that a new variable is being grabbed from the
            % MPBus buffer
            prompt = {sprintf('A module has returned the variable "%s".', ...
                              name), 'Keep'};
            default = 'Keep';
            choice = questdlg(prompt, name, 'Keep', 'Rename', 'Discard', default);

            
            switch choice
                case 'Keep'
                    handles.mpbus.workspace.push(name, value);
                case 'Rename'
                    prompt = sprintf('Rename variable "%s"', name);
                    newName = inputdlg(prompt, name, 1, {name});
                    if ~isempty(newName)
                        handles.mpbus.workspace.push(newName{1}, value);
                    end
                otherwise
            end
        end
    end

    guidata(handles.output, handles);
    refreshWorkspace(hObject, handles);
end




% --------------------------------------------------------------------
function menu_Install_Callback(hObject, ~, ~)
% hObject    handle to menu_Install (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% calling registerModule with no arguments (except handles) will force it
% to open a GUI for the user to select and install the new module
registerMod_Callback(guidata(hObject));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% END MENU BAR %%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on selection change in listbox_history.
function listbox_history_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_history (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_history contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_history


% --- Executes during object creation, after setting all properties.
function listbox_history_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_history (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in listbox_workspace.
function listbox_workspace_Callback(hObject, eventdata, handles)
% hObject    handle to listbox_workspace (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox_workspace contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox_workspace
%{
variableIndex = get(hObject,'Value');

if doubleClick('workspace', variableIndex)    
    variableInfo = handles.mpbus.workspace.variableList(variableIndex);
    
  %eval([variableInfo.name '= variableInfo.value']);
  
  % put the variable on the base workspace
  assignin('base', variableInfo.name, variableInfo.value);
  openvar(variableInfo.name);

end
%}


% --- Executes during object creation, after setting all properties.
function listbox_workspace_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox_workspace (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in popup_workspaceVariable.
function popup_workspaceVariable_Callback(hObject, eventdata, handles)
% hObject    handle to popup_workspaceVariable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popup_workspaceVariable contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popup_workspaceVariable
updateDispatch(hObject, handles);

% --- Executes during object creation, after setting all properties.
function popup_workspaceVariable_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popup_workspaceVariable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_argName_Callback(hObject, eventdata, handles)
% hObject    handle to edit_argName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_argName as text
%        str2double(get(hObject,'String')) returns contents of edit_argName as a double


% --- Executes during object creation, after setting all properties.
function edit_argName_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_argName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in button_run.
function button_run_Callback(hObject, eventdata, handles)
% hObject    handle to button_run (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% TODO: check if .call returned true or false
resetPWD;
handles.currentDispatch.call(handles.mpbus);
popEntireBuffer(hObject, handles);



% --- Executes on button press in button_import.
function button_import_Callback(hObject, eventdata, handles)
% hObject    handle to button_import (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
importWorkspace(hObject, handles);

% --- Executes on button press in button_export.
function button_export_Callback(hObject, eventdata, handles)
% hObject    handle to button_export (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% cut the selected variable from the MPWorkspace and send it to the base
% workspace

if isempty(handles.mpbus.workspace.variableList)
    return;
end

variableNameList = { handles.mpbus.workspace.variableList.name };
variableIndex = handles.mpbus.workspace.activeIndex;
variableName = variableNameList{variableIndex};

variableValue = handles.mpbus.workspace.pop(variableName);

assignin('base', variableName, variableValue);
refreshWorkspace(hObject, handles);


% --- Executes on button press in button_saveVariable.
function button_saveVariable_Callback(hObject, eventdata, handles)
% hObject    handle to button_saveVariable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
updateDispatch(hObject, handles);


% --- Executes on mouse motion over figure - except title and menu.
function figure1_WindowButtonMotionFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% dont run this function for *every* mouse movement, just every few seconds
% when there is mouse movement
persistent lastMoveTime;
currentTime = clock;
WAIT_SECONDS = 2;

if isempty(lastMoveTime)
    lastMoveTime = currentTime;
else
   if etime(currentTime, lastMoveTime) >= WAIT_SECONDS
       lastMoveTime = currentTime;
       popEntireBuffer(hObject, handles);
   end
end



% --- Executes when selected cell(s) is changed in table_workspace.
function table_workspace_CellSelectionCallback(hObject, eventdata, handles)
% hObject    handle to table_workspace (see GCBO)
% eventdata  structure with the following fields (see UITABLE)
%	Indices: row and column indices of the cell(s) currently selecteds
% handles    structure with handles and user data (see GUIDATA)
if ~isempty(eventdata.Indices)
    handles.mpbus.workspace.activeIndex = eventdata.Indices(1);
end

function table_workspace_DoubleClickCallback(~, cbData, handles)
% this is a Java callback (Undocumented MATLAB)
if get(cbData, 'ClickCount') == 2
    variableIndex = handles.mpbus.workspace.activeIndex;
    variableInfo = handles.mpbus.workspace.variableList(variableIndex);
   
    % put the variable on the base workspace
    assignin('base', variableInfo.name, variableInfo.value);
    openvar(variableInfo.name);
    
end


% --- Executes on button press in button_exportAll.
function button_exportAll_Callback(hObject, eventdata, handles)
% hObject    handle to button_exportAll (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isempty(handles.mpbus.workspace.variableList)
    return;
end

variableNameList = { handles.mpbus.workspace.variableList.name };

for variableNameCell = variableNameList
    variableName = variableNameCell{1};
    variableValue = handles.mpbus.workspace.pop(variableName);
    assignin('base', variableName, variableValue);
end


refreshWorkspace(hObject, handles);


% --- Executes on button press in button_manage.
function button_manage_Callback(hObject, eventdata, handles)
% hObject    handle to button_manage (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% open a GUI to allow users to add and remove modules
resetPWD;
manage(handles.mpbus.MODULE_FILE);
