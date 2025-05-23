import time
import queue
import threading
import socket
import csv
import numpy as np
from contextlib import ExitStack
from protocol import DSI_streamer_packet

# Status of Daq DSI
STATUS_STANDBY = 0
STATUS_OPENED = 1
STATUS_RUNNING = 2

EEG_CHANNELS = [0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15, 18, 19, 21, 22, 23, 24]

PACKET_EEG_DATA = 'EEG_DATA'
PACKET_EVENT = 'EVENT'
PACKET_DATA_RATE = 'DATA_RATE'
PACKET_SENSOR_MAP = 'SENSOR_MAP'

CHANNEL_NAMES = ['P3','C3','F3','Fz','F4','C4','P4','Cz','CM','A1','Fp1','Fp2','T3','T5','O1','O2','X3','X2','F7','F8','X1','A2','T6','T4','TRG']

SAMPLE_RATE = 300
TIMEOUT = 1
N_CHANNELS = 25

class StoppableThread(threading.Thread):
    """Thread class with a stop() method. The thread itself has to check
    regularly for the stopped() condition."""

    def __init__(self, *args, **kwargs):
        super(StoppableThread, self).__init__(*args, **kwargs)
        self._stopper = threading.Event()

    def stop(self):
        self._stopper.set()

    def stopped(self):
        return self._stopper.isSet()

class DaqDSI:
    """Acquisition class for DSI eeg headset.

    Like all daq modules, this class has the standard methods
        - OpenDevice
        - StartAcquisition
        - StopAcquisition
        - CloseDevice
        - GetData         
    """
    def __init__(self, addr="127.0.0.1", port=8844):
        """ Constructor for daq pupil
        Inputs:
            addr : string
                Address of the dsi streamer
            port : int
                Port for requesting information
        """
        self._addr = addr
        self._port = port 

        self._data_queue = None
        self._acq_thread = None

        self._dsi_socket = None
        self._dsi_socket_file = None
        
        self._timeout = TIMEOUT
        self.sample_rate = SAMPLE_RATE
        self.n_channels = N_CHANNELS

        self.channel_names = CHANNEL_NAMES
        self.file_name = None

        self.status = STATUS_STANDBY

    def open_device(self):
        """ Creates socket
        """
        if self.status is STATUS_STANDBY:                        
            self.status = STATUS_OPENED

    def start_acquisition(self, file_name=None):
        """ Starts thread and connection to socket
        """
        if self.status is STATUS_OPENED:

            self._dsi_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self._dsi_socket.settimeout(self._timeout)
            self._dsi_socket.connect((self._addr, self._port))
            self._dsi_socket_file = self._dsi_socket.makefile(mode='b')

            packet = DSI_streamer_packet.parse_stream(self._dsi_socket_file)
            if packet.type == PACKET_EVENT and packet.event_code == PACKET_SENSOR_MAP:
                self.channel_names = packet.message.split(',')

            packet = DSI_streamer_packet.parse_stream(self._dsi_socket_file)
            if packet.type == PACKET_EVENT and packet.event_code == PACKET_DATA_RATE:
                self.sample_rate = int(packet.message.split(',')[1])    

            self.file_name = file_name

            self._data_queue = queue.Queue()
            self._acq_thread = StoppableThread(target=self._acquire_data)

            self.status = STATUS_RUNNING
            self._acq_thread.start()


    def get_data(self):
        """ Gets data stored in buffer
        Outputs:
            eeg_data : np array of n_samples by n_channels              
        """

        eeg_data = np.empty(0)

        if self.status is STATUS_RUNNING:
            
            n_samples = self._data_queue.qsize()
            eeg_data = np.zeros((n_samples, len(EEG_CHANNELS)))
            for i in range(n_samples):
                eeg_data[i] = self._data_queue.get()
                self._data_queue.task_done()  

        return eeg_data                              

    def stop_acquisition(self): 
        """ Stops polling
        """
        if self.status is STATUS_RUNNING:
            
            self._acq_thread.stop()
            self._acq_thread.join()

            self._dsi_socket = None
            self._dsi_socket_file = None

            self.file_name = None

            self.status = STATUS_OPENED

    def close_device(self):
        """ Closes connection
        """
        if self.status is STATUS_OPENED:
           
            self._data_queue = None
            self._acq_thread = None
            self.status = STATUS_STANDBY      

    def _acquire_data(self):
        """ Function running in separate thread
        """    
        if self.status is STATUS_RUNNING:
            
            with ExitStack() as stack:
                
                if self.file_name:
                    csv_file = stack.enter_context(open(self.file_name, 'w', newline='')) 
                    data_writer = csv.writer(csv_file, delimiter=',')
                    data_writer.writerow(['daq_type', 'DSI'])
                    data_writer.writerow(['sample_rate', self.sample_rate])
                    data_writer.writerow([self.channel_names[i] for i in EEG_CHANNELS])

                while not self._acq_thread.stopped():
                    
                    # Get data from socket and only add it to queue if it's EEG
                    packet = DSI_streamer_packet.parse_stream(self._dsi_socket_file)
                    if packet.type == PACKET_EEG_DATA:
                        eeg_data = np.array(packet.sensor_data)[EEG_CHANNELS]
                        self._data_queue.put(eeg_data)

                        if self.file_name:
                            data_writer.writerow(eeg_data)                                                             
        
# Example usage        
if __name__ == "__main__":

    # Instantiate and start collecting data
    daq_dsi = DaqDSI()

    daq_dsi.open_device()
    daq_dsi.start_acquisition('test.csv')

    # Get data from buffer
    time.sleep(1)
    eeg_data = daq_dsi.get_data()

    print("Number of samples in 1 second: {0}".format(eeg_data.size/daq_dsi.n_channels))
    #print(eeg_data)

    time.sleep(1)
    eeg_data = daq_dsi.get_data()

    print("Number of samples in 1 second: {0}".format(eeg_data.size/daq_dsi.n_channels))
    #print(eeg_data)

    time.sleep(1)
    eeg_data = daq_dsi.get_data()

    print("Number of samples in 1 second: {0}".format(eeg_data.size/daq_dsi.n_channels))
    #print(eeg_data)

    daq_dsi.stop_acquisition()
    daq_dsi.close_device()
    