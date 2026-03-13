
-- dichiarazione variabili in ingresso
--=============================================
start=%g
stop=%g
numPoints=%d
%.;measdelay=%g
livello={%s} --labview inserisce nello script il mio pezzo di testo. Scritta in questo modo, la riga che ne risulta viene interpretata da lua come un array
limitI=%g
nplc=%g
numSweep=%d
remoteSense=false

--=============================================

-- dichiarazione tempi dei timer
--=============================================
-- mi calcolo la finestra di misura
finestra_misura=(1/localnode.linefreq)*nplc
-- imposto la lunghezza dell'impulso. la dc sweep si origina da una pulsed sweep.
pulseWidth=measdelay+finestra_misura 
--il periodo è l'impulso + più un t_off, una bassa percentuale dell'impulso
pulsePeriod=pulseWidth+(pulseWidth*1/100) 

--=============================================

-- dichiarazione timer e gestore eventi
--=============================================
-- Timer 1: timer periodo (larghezza gradino)
timer_periodo=trigger.timer[1]
-- Timer 2: Timer ritardo misura
timer_misura=trigger.timer[2]
-- Timer 3: Pulse Width Timer
timer_larghezza_impulso=trigger.timer[3]

-- Gestore eventi 1: Event Blender per la partenza di iniziale di smua e l'aggiornamento di smua al trigger di smub
gestore_avvio_smua=trigger.blender[1]
--=============================================

--reset()
-- Configure Channel A Settings
--=============================
smua.reset()
smua.source.func			    = smua.OUTPUT_DCVOLTS
-- imposto modalità misura a 2 fili
if remoteSense == true then
smua.sense						= smua.SENSE_REMOTE
else
smua.sense						= smua.SENSE_LOCAL
end

smua.source.autorangev			= smua.AUTORANGE_OFF
smua.source.rangev				= math.max(math.abs(start), math.abs(stop))
smua.source.levelv				= 0
-- Set the DC bias limit.  This is not the limit used during the pulses. ma è il valore di idle della smua
smua.source.limiti				= 0.1

-- Disabling Auto-Ranging and Auto-Zero ensures accurate and consistent timing
smua.measure.autozero			= smua.AUTOZERO_ONCE
smua.measure.autorangei			= smua.AUTORANGE_OFF
smua.measure.rangei				= limitI
smua.measure.nplc				= nplc
-- A timer will be used to set the measure delay and synchronize the measurement
-- between the two SMUs so set the built in delay to 0.
smua.measure.delay				= 0

-- Prepare the Reading Buffers
smua.nvbuffer1.clear()
smua.nvbuffer1.collecttimestamps= 1
smua.nvbuffer2.clear()
smua.nvbuffer2.collecttimestamps = 1
--=============================
-- End Channel A Settings

-- Configure Channel B Settings
--=============================
smub.reset()
smub.source.func				= smub.OUTPUT_DCVOLTS
smua.sense						= smua.SENSE_LOCAL
smub.source.autorangev			= 0
smub.source.rangev				= math.max(math.abs(start), math.abs(stop))
smub.source.levelv				= 0
-- Set the DC bias limit.  This is not the limit used during the pulses. ma è il valore di idle della smu
smub.source.limiti				= 0.1

-- Disabling Auto-Ranging and Auto-Zero ensures accurate and consistent timing
smub.measure.autozero			= smub.AUTOZERO_ONCE
smub.measure.autorangei			= smub.AUTORANGE_OFF
smub.measure.rangei				= limitI
smub.measure.nplc				= nplc
-- A timer will be used to set the measure delay and synchronize the measurement
-- between the two SMUs so set the built in delay to 0.
smub.measure.delay				= 0

-- Prepare the Reading Buffers
smub.nvbuffer1.clear()
smub.nvbuffer1.collecttimestamps= 1
smub.nvbuffer2.clear()
smub.nvbuffer2.collecttimestamps= 1
--=============================
-- End Channel B Settings

-- Configure the Trigger Model
--============================
--Configurazione timer e trigger. Sono la parte essenziale dello script, dato che gestiscono i tempi di misura
trigger.clear()

-- Timer 1 controls the pulse period, cioè la durata del gradino
timer_periodo.count			= numPoints > 1 and numPoints - 1 or 1
timer_periodo.delay			= pulsePeriod
--il passthrough mi consente di ricevere l'interrupt quando il timer parte, ossia l'event id. 
--Mi servirà da stimolo per gli altri timer, che partiranno all'inizo del gradino
-- definendo il momento della misura e la durata dell'impulso di alimentazione
timer_periodo.passthrough	= true
-- il timer 1 parte quando la smub, in questo caso, inizia la sweep: cioè entra nello stato armed
timer_periodo.stimulus		= smub.trigger.ARMED_EVENT_ID 

-- Timer 2 controls the measurement. il timer 2 gestisce il ritardo di misura. scaduto quello, inizia la finestra di misura
timer_misura.count			= 1
timer_misura.delay			= measdelay
-- il passthrough è false perchè l'interrupt lo produrre alla fine. 
-- Scaduto il delay di misura, inizia la finestra di misura
timer_misura.passthrough	= false
--il timer 1 grazie al passthrough mi fa partire il timer 2 all'inizio del gradino
timer_misura.stimulus		= timer_periodo.EVENT_ID 

-- Timer 3 controls the pulse width
timer_larghezza_impulso.count			= 1
timer_larghezza_impulso.delay			= pulseWidth
-- il passthrough è false perchè l'interrupt me lo produce alla fine, perchè 
timer_larghezza_impulso.passthrough	= false
--il timer 1 grazie al passthrough mi fa partire il timer 3 all'inizio del gradino
timer_larghezza_impulso.stimulus		= timer_periodo.EVENT_ID

-- Configure SMUA Trigger Model for Sweep
-- imposto un singolo valore di tensione, costante per tutta la durata della sweep.
-- quindi quello che ottengo è la sweep di un singolo valore. il risultato è appunto una valore costante
smua.trigger.source.listv(livello)
smua.trigger.source.limiti		= limitI
smua.trigger.measure.action		= smua.ASYNC
smua.trigger.measure.iv(smua.nvbuffer1, smua.nvbuffer2)
--fine impulso: se voglio una dc sweep, anzichè mandare in idle l'uscita, la tengo costante
smua.trigger.endpulse.action	= smua.SOURCE_HOLD
-- endsweep mi dice cosa fare quando finisce l'operazione sweep
smua.trigger.endsweep.action	= smua.SOURCE_HOLD
smua.trigger.arm.count = 1
smua.trigger.count				= numSweep
-- arm sweep indica quanto sweep deve fare 
smub.trigger.arm.stimulus		= 0


--event blender per la partenza
gestore_avvio_smua.orenable = true
gestore_avvio_smua.stimulus[1] = smua.trigger.ARMED_EVENT_ID
gestore_avvio_smua.stimulus[2] = smub.trigger.ARMED_EVENT_ID 

--dico quali stimoli/timer attivano le azioni
smua.trigger.source.stimulus = gestore_avvio_smua.EVENT_ID 
smua.trigger.measure.stimulus	= timer_misura.EVENT_ID
smua.trigger.endpulse.stimulus	= smub.trigger.SWEEP_COMPLETE_EVENT_ID

smua.trigger.source.action		= smua.ENABLE

-- Configure SMUB Trigger Model for Sweep
smub.trigger.source.linearv(start, stop, numPoints)
smub.trigger.source.limiti		= limitI
smub.trigger.measure.action		= smub.ENABLE
smub.trigger.measure.iv(smub.nvbuffer1, smub.nvbuffer2)
--fine impulso: se voglio una dc sweep, anzichè mandare in idle l'uscita, la tengo costante
smub.trigger.endpulse.action	= smub.SOURCE_HOLD 
-- endsweep mi dice cosa fare quando finisce l'operazione sweep
smub.trigger.endsweep.action	= smub.SOURCE_HOLD
smub.trigger.arm.count = numSweep
-- num punti sweep
smub.trigger.count				= numPoints
-- arm sweep indica quanto sweep deve fare
smub.trigger.arm.stimulus		= 0
--dico quali timer attivanzo le azioni
smub.trigger.source.stimulus	= timer_periodo.EVENT_ID
smub.trigger.measure.stimulus	= timer_misura.EVENT_ID
smub.trigger.endpulse.stimulus	= timer_larghezza_impulso.EVENT_ID
smub.trigger.source.action		= smub.ENABLE
--==============================
-- End Trigger Model Configuration

smua.source.output				= smua.OUTPUT_ON
smub.source.output				= smub.OUTPUT_ON

-- Start the trigger model execution
smua.trigger.initiate()
delay(0.05)
smub.trigger.initiate()

-- Wait until the sweep has completed
waitcomplete()
delay(0.05)

smub.source.output				= smub.OUTPUT_OFF
delay(0.05)
smua.source.output				= smua.OUTPUT_OFF

--printbuffer(1, numPoints, smua.nvbuffer2.readings)
--printbuffer(1, numPoints, smua.nvbuffer1.readings)
--printbuffer(1, numPoints, smua.nvbuffer1.timestamps)

--printbuffer(1, numPoints, smub.nvbuffer2.readings)
--printbuffer(1, numPoints, smub.nvbuffer1.readings)
--printbuffer(1, numPoints, smub.nvbuffer1.timestamps)
