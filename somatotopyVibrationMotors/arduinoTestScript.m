%% Arduino setup
global isMonitorArduino
isMonitorArduino = 1;
arduinoSerialObject = serial('COM3', 'BaudRate', 9600);
arduinoSerialObject.BytesAvailableFcn = @cbArduinoDataAvailable;
fopen(arduinoSerialObject);

%% Write new state:
fwrite(arduinoSerialObject, 6, 'uint8')
pause(0.2)
fwrite(arduinoSerialObject, 0, 'uint8')

%% Test state:
fwrite(arduinoSerialObject, 99, 'uint8')

%% Close:
fclose(arduinoSerialObject) 