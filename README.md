# Feedbacker
Feedback feature extractor for SuperCollider and Wekinator.

This feature extractor uses audio feedback as a source signal. SC listens to the output of Wekinator and uses the trained data to control a highpass filter and granulation parameters.
Works by far the best if you use an audio interface with condenser microphone(s) and speakers connected.
The SuperCollider code can be used as a simple feature extractor but is intended for experiments with self-adjusting or self-organising behaviour. By training Wekinator on feedback feature extraction in SC and mapping Wekinator's outputs back into SC, a possibly self-adjusting loop is created.

Get SuperCollider here: https://supercollider.github.io/download
Get Wekinator: http://www.wekinator.org/  

Recording and training can be controlled from the SC GUI, while training algorithms need to to be changed in Wekinator. 

See below for a list of output and input features.

WEKINATOR SETUP:
Inputs should be set to 18.
Outputs default to 5. If you wish to add more, make sure to add more inputs to SC as well (see below).

In case you use Wekinator to control the granulation in SC:
Due to the nature of feedback, any change in the output of Wekinator will have an immediate impact on SC input, which in turn effects Wekinators input. Since Wekinator needs to train on the current state of the feedback (input) combined with the desired output (which will change the current feedback state), it is necessary to disable incoming OSC messages in SC. This is done with the “Stop Wekinator Input” button. Consequently, it is not possible to do real-time training and you will need to do a bit of guess-work and familiarise yourself with the granulation engine in order to get satisfying results.

SC setup:
SC by default listens for 5 inputs from Wekinator. If you wish to add more, find ~makeBusses in the code and add more, remembering to change the bus numbers:
 ~bus.add(\wekOut_6 -> Bus.control(s, 1)); 
 ~bus.add(\wekOut_7 -> Bus.control(s, 1)); 
etc…

Then find the line
k = OSCdef.new(\fromWek, …
add more busses 
~bus[\wekOut_6].set(msg[6]); 
~bus[\wekOut_7].set(msg[7]); 

Of course, you need to increase the number of outputs in Wekinator as well.

INPUTS:
1: High-pass filter cut-off (between 20 and 100 Hz).
2: Grain duration (5 to 150 ms).
3: Grain read speed. Controls how fast the grains are read in a 1-second buffer. 	Speed is between 0.1 (one tenth) and 1 (full speed).
4: Grain density. Determines how often a grain is fired (between 60 and 0.5 times per second).
5: Unmapped.
The default parameter ranges can be changed within the SC code.

HOW TO USE THE EXTRACTOR:
1) Setup SuperCollider and Wekinator as described above
2) Place the mouse anywhere in the code and press cmd + enter.
3) Turn up the volume slowly and wait for the feedback to manifest. 
4) Press “Stop Wekinator Input” and adjust the sliders in Wekinator to what you assume would be a proper response to the current feedback    state.
5) Record a second or two of training data.
6) Train the model.
7) Restart the Wekinator Input.
8) Observe the behaviour of the feedback. You can delete the training set or if you are happy with it, go back to step 4 and start a new      training.

OUTPUTS:
The following features are extracted as floating-point numbers:
1-13: Mel cepstral coeffifients (https://en.wikipedia.org/wiki/Mel-frequency_cepstrum)
14: 	Amplitude
15: 	Frequency-tracker: Most prominent frequency
16: 	Spectral entropy. A measure of the spectral information in the signal. The more ordered the information in the signal, the lower the       number (http://staffhome.ecm.uwa.edu.au/~00014742/research/theses/tr05-01.pdf)
17: 	Spectral centroid: The centre of mass of the spectrum
18:	  Spectral flatness: The spectrum’s geometric mean, divided by its arithmetic mean. 
19:	  Frequency difference between scaled input and output
20: 	Amplitude difference between scaled input and output
21: 	Entropy difference between scaled input and output
22: 	Centroid difference between scaled input and output
23: 	Flatness difference between scaled input and output
24: 	Frequency at output scaled to 0-1
24: 	Amplitude at output scaled to 0-1
25: 	Entropy at output scaled to 0-1
26: 	Centroid at output scaled to 0-1
27: 	Flatness at output scaled to 0-1

Only output 1-18 are sent to Wekinator. The remaining numbers can be used as control signals within SC. 








