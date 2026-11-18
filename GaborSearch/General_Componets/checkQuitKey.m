function checkQuitKey(keyCode, exitKey)
if keyCode(exitKey)
    error('GaborSearchRIFT:UserQuit', 'Experiment aborted by q key.');
end
end