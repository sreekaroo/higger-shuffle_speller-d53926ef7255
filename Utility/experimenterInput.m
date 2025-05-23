prompt = {'Session Type (normal, low acuity, low motility):', ...
    'Staff initials:', ...
    'Session Number:  (1 for first session...)'};
dlg_title = 'Input';
num_lines = 1;
defaultans = {'','BP', '0'};
answer = inputdlg(prompt,dlg_title,num_lines,defaultans);

sessionID = answer{1};
staffInitials = answer{2};
sessionNumber = answer{3};
date = datestr(now,'mmm-dd-yyyy_HH-MM_AM');