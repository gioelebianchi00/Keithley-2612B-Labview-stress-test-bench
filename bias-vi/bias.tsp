
-- dichiarazione variabili in ingresso
--=============================================
livello_drain=5
livello_gate=1
limiti_drain=1
limiti_gate=1
rangei_drain=0.001
rangei_gate=1
numPoints=11
pulsePeriod=0.005
fmd=65
inversione_porte=false
--=============================================

--dichiarazione variabili operative
--=============================================
t_morto=0
numSweep=1
remoteSense=false

if inversione_porte then
    gate=smub
    drain=smua
else 
    gate=smua
    drain=smub
end
--============================================

-- dichiarazione tempi dei timer
--=============================================
t_morto=pulsePeriod*1/100
measdelay=pulsePeriod*fmd/100
finestra_misura=pulsePeriod-measdelay-t_morto
pulseWidth=pulsePeriod-t_morto

nplc=finestra_misura*localnode.linefreq 

--=============================================

-- dichiarazione timer e gestore eventi
--=============================================
-- Timer 1: timer periodo (larghezza gradino)
timer_periodo=trigger.timer[1]
-- Timer 2: Timer ritardo misura
timer_misura=trigger.timer[2]
-- Timer 3: Pulse Width Timer
timer_larghezza_impulso=trigger.timer[3]

-- Gestore eventi 1: Event Blender per la partenza di iniziale di gate e l'aggiornamento di gate al trigger di drain
gestore_avvio_gate=trigger.blender[1]
--=============================================

--reset()
-- Configure Channel A Settings
--=============================
gate.reset()
gate.source.func			    = gate.OUTPUT_DCVOLTS
-- imposto modalità misura a 2 fili
if remoteSense == true then
gate.sense						= gate.SENSE_REMOTE
else
gate.sense						= gate.SENSE_LOCAL
end

gate.source.autorangev			= gate.AUTORANGE_OFF
gate.source.rangev				= math.max(math.abs(livello_gate))
gate.source.levelv				= 0
-- Set the DC bias limit.  This is not the limit used during the pulses. ma è il valore di idle della gate
gate.source.limiti				= limiti_gate

-- Disabling Auto-Ranging and Auto-Zero ensures accurate and consistent timing
gate.measure.autozero			= gate.AUTOZERO_ONCE
gate.measure.autorangei			= gate.AUTORANGE_OFF
gate.measure.rangei				= limiti_gate
gate.measure.nplc				= nplc
-- A timer will be used to set the measure delay and synchronize the measurement
-- between the two SMUs so set the built in delay to 0.
gate.measure.delay				= 0

-- Prepare the Reading Buffers
gate.nvbuffer1.clear()
gate.nvbuffer1.collecttimestamps= 1
gate.nvbuffer2.clear()
gate.nvbuffer2.collecttimestamps = 1
--=============================
-- End Channel A Settings

-- Configure Channel B Settings
--=============================
drain.reset()
drain.source.func				= drain.OUTPUT_DCVOLTS
-- imposto modalità misura a 2 fili
if remoteSense == true then
drain.sense						= drain.SENSE_REMOTE
else
drain.sense						= drain.SENSE_LOCAL
end

drain.source.autorangev			= 0
drain.source.rangev				= math.max(math.abs(livello_drain))
drain.source.levelv				= 0
-- Set the DC bias limit.  This is not the limit used during the pulses. ma è il valore di idle della smu
drain.source.limiti				= limiti_drain

-- Disabling Auto-Ranging and Auto-Zero ensures accurate and consistent timing

drain.measure.autozero			= drain.AUTOZERO_ONCE
drain.measure.autorangei			= drain.AUTORANGE_OFF
drain.measure.rangei = limiti_drain
drain.measure.nplc				= nplc
-- A timer will be used to set the measure delay and synchronize the measurement
-- between the two SMUs so set the built in delay to 0.
drain.measure.delay				= 0

-- Prepare the Reading Buffers
drain.nvbuffer1.clear()
drain.nvbuffer1.collecttimestamps= 1
drain.nvbuffer2.clear()
drain.nvbuffer2.collecttimestamps= 1
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
-- il timer 1 parte quando la drain, in questo caso, inizia la sweep: cioè entra nello stato armed
timer_periodo.stimulus		= drain.trigger.ARMED_EVENT_ID 

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

-- Configure gate Trigger Model for Sweep
-- imposto un singolo valore di tensione, costante per tutta la durata della sweep.
-- quindi quello che ottengo è la sweep di un singolo valore. il risultato è appunto una valore costante
gate.trigger.source.listv({livello_gate})
gate.trigger.source.limiti		= limiti_gate
gate.trigger.measure.action		= gate.ASYNC
gate.trigger.measure.iv(gate.nvbuffer1, gate.nvbuffer2)
--fine impulso: se voglio una dc sweep, anzichè mandare in idle l'uscita, la tengo costante
gate.trigger.endpulse.action	= gate.SOURCE_HOLD
-- endsweep mi dice cosa fare quando finisce l'operazione sweep
gate.trigger.endsweep.action	= gate.SOURCE_HOLD
gate.trigger.arm.count = 1
gate.trigger.count				= numSweep
-- arm sweep indica quanto sweep deve fare 
drain.trigger.arm.stimulus		= 0


--event blender per la partenza
gestore_avvio_gate.orenable = true
gestore_avvio_gate.stimulus[1] = gate.trigger.ARMED_EVENT_ID
gestore_avvio_gate.stimulus[2] = drain.trigger.ARMED_EVENT_ID 

--dico quali stimoli/timer attivano le azioni
gate.trigger.source.stimulus = gestore_avvio_gate.EVENT_ID 
gate.trigger.measure.stimulus	= timer_misura.EVENT_ID
gate.trigger.endpulse.stimulus	= drain.trigger.SWEEP_COMPLETE_EVENT_ID

gate.trigger.source.action		= gate.ENABLE

-- Configure drain Trigger Model for Sweep
drain.trigger.source.listv({livello_drain})
drain.trigger.source.limiti		= limiti_drain
drain.trigger.measure.action		= drain.ENABLE
drain.trigger.measure.iv(drain.nvbuffer1, drain.nvbuffer2)
--fine impulso: se voglio una dc sweep, anzichè mandare in idle l'uscita, la tengo costante
drain.trigger.endpulse.action	= drain.SOURCE_HOLD 
-- endsweep mi dice cosa fare quando finisce l'operazione sweep
drain.trigger.endsweep.action	= drain.SOURCE_HOLD
drain.trigger.arm.count = numSweep
-- num punti sweep
drain.trigger.count				= numPoints
-- arm sweep indica quanto sweep deve fare
drain.trigger.arm.stimulus		= 0
--dico quali timer attivanzo le azioni
drain.trigger.source.stimulus	= timer_periodo.EVENT_ID
drain.trigger.measure.stimulus	= timer_misura.EVENT_ID
drain.trigger.endpulse.stimulus	= timer_larghezza_impulso.EVENT_ID
drain.trigger.source.action		= drain.ENABLE
--==============================
-- End Trigger Model Configuration

gate.source.output				= gate.OUTPUT_ON
drain.source.output				= drain.OUTPUT_ON

-- Start the trigger model execution
gate.trigger.initiate()
delay(0.05)
drain.trigger.initiate()

-- Wait until the sweep has completed
waitcomplete()
--delay(0.05)

drain.source.output				= drain.OUTPUT_OFF
delay(0.05)
gate.source.output				= gate.OUTPUT_OFF

--printbuffer(1, numPoints, gate.nvbuffer2.readings)
--printbuffer(1, numPoints, gate.nvbuffer1.readings)
--printbuffer(1, numPoints, gate.nvbuffer1.timestamps)

--printbuffer(1, numPoints, drain.nvbuffer2.readings)
--printbuffer(1, numPoints, drain.nvbuffer1.readings)
--printbuffer(1, numPoints, drain.nvbuffer1.timestamps)



print("tensioni")
printbuffer(1, numPoints, drain.nvbuffer1.readings)
print("correnti")
printbuffer(1, numPoints, drain.nvbuffer2.readings)
print("tempistiche")
printbuffer(1, numPoints, drain.nvbuffer1.timestamps)
