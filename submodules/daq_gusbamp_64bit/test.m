% example_script.m
% A simple Octave script to demonstrate basic functionality

% Clear the workspace and command window
clear;
clc;

% Define variables
x = 0:0.1:10; % Create a vector from 0 to 10 with a step of 0.1
y = sin(x);   % Compute the sine of each value in x

% Display a message
disp('This is an example Octave script.');

% Plot the sine wave
figure; % Open a new figure window
plot(x, y, 'b-', 'LineWidth', 2); % Plot y = sin(x) with a blue line
xlabel('x'); % Label for x-axis
ylabel('sin(x)'); % Label for y-axis
title('Sine Wave'); % Title of the plot
grid on; % Turn on the grid

% Save the plot as a PNG file
saveas(gcf, 'sine_wave_plot.png');

% Perform basic calculations and display results
mean_value = mean(y); % Calculate the mean of y
disp(['Mean value of sin(x): ', num2str(mean_value)]);

% End of script
disp('Script execution completed.');
