function generateSymbolic(D)
    % Exports any symbolic expression to file.
    %% Calls
    [c, X] = cBinghamNormSymbolic(D);
    grad_log_c = cBinghamGradLogNormSymbolic(c, X);
    grad_c_divided_by_c = cBinghamGradNormDividedByNormSymbolic(c, X);
    
    %% Export
    mFileExport(c, X, 'cBinghamNorm');
    mFileExport(grad_log_c, X, 'cBinghamGradLogNorm');
    mFileExport(grad_c_divided_by_c, X, 'cBinghamGradNormDividedByNorm');
end
function mFileExport(expression, variables, name)
    D = numel(variables);
    thisFilePath = mfilename('fullpath');
    filename = sprintf('%s%d.m', name, D);
    filename = fullfile(fileparts(thisFilePath), filename);
    matlabFunction(expression, 'file', filename, 'vars', {variables});
end
