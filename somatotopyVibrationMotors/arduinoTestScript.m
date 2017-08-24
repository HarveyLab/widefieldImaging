%% Arduino setup
global isMonitorArduino
isMonitorArduino = 1;
arduinoSerialObject = serial('COM3', 'BaudRate', 9600);
fopen(arduinoSerialObject);

%arduinoSerialObject.BytesAvailableFcn = @cbArduinoDataAvailable;


%% Write new state:
fwrite(arduinoSerialObject, 1, 'uint8')
pause(1)
fwrite(arduinoSerialObject, 0, 'uint8')
fwrite(arduinoSerialObject, 2, 'uint8')
pause(1)
fwrite(arduinoSerialObject, 0, 'uint8')
fwrite(arduinoSerialObject, 3, 'uint8')
pause(1)
fwrite(arduinoSerialObject, 0, 'uint8')
fwrite(arduinoSerialObject, 4, 'uint8')
pause(1)
fwrite(arduinoSerialObject, 0, 'uint8')
fwrite(arduinoSerialObject, 5, 'uint8')
pause(1)
fwrite(arduinoSerialObject, 0, 'uint8')
fwrite(arduinoSerialObject, 6, 'uint8')
pause(1)
fwrite(arduinoSerialObject, 0, 'uint8')
%% Test state:
fwrite(arduinoSerialObject, 99, 'uint8')

%% Close:
fclose(arduinoSerialObject) 