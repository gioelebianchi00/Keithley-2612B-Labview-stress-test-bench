-- dichiarazione variabili in ingresso
--=============================================
%.;start_drain=%g
%.;stop_drain=%g
livello_gate={%s}
%.;limiti_drain=%g
%.;limiti_gate=%g
%.;rangei_drain=%g
%.;rangei_gate=%g
inversione_porte=%d
autozero_drain=%d
autozero_gate=%d
source_drain=%d
source_gate=%d
autorange_drain=%d
autorange_gate=%d
source_autorange_drain=%d
source_autorange_gate=%d

%.;measdelay=%g
%.;nplc=%g

numPoints=%d
numSweep=%d
%.;source_range_drain=%g
%.;source_range_gate=%g
remoteSense=false
--=============================================
--dichiarazione variabili operative
--=============================================
remoteSense=false
if inversione_porte==1 then
gate=smub
drain=smua
else 
gate=smua
drain=smub
end

dim_livello=table.getn(livello_gate)

-- se il numero di livelli è minore del numero di piramidi, allora ripeto i valori
if (dim_livello<numSweep) then

    for i=1, (numSweep-dim_livello) do
        table.insert(livello_gate, livello_gate[i])
    end

end

--============================================

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
gestore_avvio_gate=trigger.blender[1]
--=============================================
-- Configure Channel A Settings
--=============================
gate.reset()

if source_gate==1 then
gate.source.func = gate.OUTPUT_DCVOLTS
else
gate.source.func = gate.OUTPUT_DCAMPS
end

-- imposto modalità misura a 2 fili
if remoteSense == true then
gate.sense						= gate.SENSE_REMOTE
else
gate.sense						= gate.SENSE_LOCAL
end


if source_gate==1 then ---------------------------------------

if source_autorange_gate==1 then 
gate.source.autorangev			= gate.AUTORANGE_ON
gate.source.lowrangev=source_range_gate
else
gate.source.autorangev			= gate.AUTORANGE_OFF
gate.source.rangev				=source_range_gate
end 

gate.source.levelv				= 0
-- Set the DC bias limit.  This is not the limit used during the pulses. ma è il valore di idle della gate
gate.source.limiti				= limiti_gate

else------------------------

if source_autorange_gate==1 then
gate.source.autorangei			= gate.AUTORANGE_ON
gate.source.lowrangei=source_range_gate
else
gate.source.autorangei			= gate.AUTORANGE_OFF
gate.source.rangei			=source_range_gate
end

gate.source.leveli				= 0
-- Set the DC bias limit.  This is not the limit used during the pulses. ma è il valore di idle della gate
gate.source.limitv				= limiti_gate
end --------------------------------------------------


-- Disabling Auto-Ranging and Auto-Zero ensures accurate and consistent timing
if autozero_gate==0 then
gate.measure.autozero			= gate.AUTOZERO_OFF
elseif autozero_gate==1 then
gate.measure.autozero			= gate.AUTOZERO_ONCE
else
gate.measure.autozero			= gate.AUTOZERO_AUTO
end

if autorange_gate==0 then ------------------------

if source_gate==1 then
gate.measure.autorangei			= gate.AUTORANGE_OFF
gate.measure.rangei				= rangei_gate
else
gate.measure.autorangev			= gate.AUTORANGE_OFF
gate.measure.rangev				= rangei_gate
end

elseif  autorange_gate==1 then -----------

if source_gate==1 then
gate.measure.autorangei			= gate.AUTORANGE_ON
gate.measure.lowrangei				= rangei_gate
else
gate.measure.autorangev			= gate.AUTORANGE_ON
gate.measure.lowrangev				= rangei_gate
end

else --------------------------

end -------------------------------

gate.measure.nplc				= nplc
-- A timer will be used to set the measure delay and synchronize the measurement
-- between the two SMUs so set the built in delay to 0.
gate.measure.delay				= 0

-- Prepare the Reading Buffers
gate.nvbuffer1.clear()
gate.nvbuffer1.collecttimestamps= 1
gate.nvbuffer1.appendmode=1
gate.nvbuffer2.clear()
gate.nvbuffer2.collecttimestamps = 1
gate.nvbuffer2.appendmode=1
--=============================
-- End Channel A Settings

-- Configure Channel B Settings
--=============================
drain.reset()
if source_drain==1 then
drain.source.func				= drain.OUTPUT_DCVOLTS
else
drain.source.func				= drain.OUTPUT_DCAMPS
end
-- imposto modalità misura a 2 fili
if remoteSense == true then
drain.sense						= drain.SENSE_REMOTE
else
drain.sense						= drain.SENSE_LOCAL
end

if source_drain==1 then------------------------------------------

if source_autorange_drain==1 then 
drain.source.autorangev			= drain.AUTORANGE_ON
drain.source.rangev				= math.min(math.abs(stop_drain),math.abs(start_drain))
else
drain.source.autorangev			= drain.AUTORANGE_OFF
drain.source.rangev				=  math.max(math.abs(stop_drain),math.abs(start_drain))
end

drain.source.levelv				= 0
-- Set the DC bias limit.  This is not the limit used during the pulses. ma è il valore di idle della smu
drain.source.limiti				= limiti_drain
else----------------------------------------------------
if source_autorange_drain==1 then 
drain.source.autorangei			= drain.AUTORANGE_ON
drain.source.rangei				= math.min(math.abs(stop_drain),math.abs(start_drain))
else
drain.source.autorangei			= drain.AUTORANGE_OFF
drain.source.rangei				= math.max(math.abs(stop_drain),math.abs(start_drain))
end
drain.source.leveli				= 0
-- Set the DC bias limit.  This is not the limit used during the pulses. ma è il valore di idle della smu
drain.source.limitv				= limiti_drain
end----------------------------------------------

-- Disabling Auto-Ranging and Auto-Zero ensures accurate and consistent timing

if autozero_drain==0 then
drain.measure.autozero			= drain.AUTOZERO_OFF
elseif autozero_drain==1 then
drain.measure.autozero			= drain.AUTOZERO_ONCE
elseif autozero_drain==2 then
drain.measure.autozero			= drain.AUTOZERO_AUTO
end

if autorange_drain==0 then --------------------------------

if source_drain==1 then
drain.measure.autorangei			= drain.AUTORANGE_OFF
drain.measure.rangei				= rangei_drain
else
drain.measure.autorangev			= drain.AUTORANGE_OFF
drain.measure.rangev				= rangei_drain
end



elseif  autorange_drain==1 then ----------------------------

if source_drain==1 then
drain.measure.autorangei			= drain.AUTORANGE_ON
drain.measure.lowrangei				= rangei_drain
else
drain.measure.autorangev			= drain.AUTORANGE_ON
drain.measure.lowrangev				= rangei_drain
end

else

end --------------------------------------------------------------

drain.measure.nplc				= nplc
-- A timer will be used to set the measure delay and synchronize the measurement
-- between the two SMUs so set the built in delay to 0.
drain.measure.delay				= 0

-- Prepare the Reading Buffers
drain.nvbuffer1.clear()
drain.nvbuffer1.collecttimestamps= 1
drain.nvbuffer1.appendmode=1
drain.nvbuffer2.clear()
drain.nvbuffer2.collecttimestamps= 1
drain.nvbuffer2.appendmode=1
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

limitI=1
gate.source.output				= gate.OUTPUT_ON
drain.source.output				= drain.OUTPUT_ON


for i=1,numSweep,1 do 

-- Configure gate Trigger Model for Sweep
-- imposto un singolo valore di tensione, costante per tutta la durata della sweep.
-- quindi quello che ottengo è la sweep di un singolo valore. il risultato è appunto una valore costante
--in lua a differenza del linguaggio c/c++, il primo elemento di un array ha indice 1, non 0

if source_gate==1 then-----------------------
gate.trigger.source.listv({livello_gate[i]})
gate.trigger.source.limiti		= limiti_gate
else -------------------------------------------
gate.trigger.source.listi({livello_gate[i]})
gate.trigger.source.limitv		= limiti_gate
end--------------------------------------------

gate.trigger.measure.action		= gate.ASYNC
gate.trigger.measure.iv(gate.nvbuffer1, gate.nvbuffer2)
--fine impulso: se voglio una dc sweep, anzichè mandare in idle l'uscita, la tengo costante
gate.trigger.endpulse.action	= gate.SOURCE_HOLD
-- endsweep mi dice cosa fare quando finisce l'operazione sweep
gate.trigger.endsweep.action	= gate.SOURCE_HOLD
gate.trigger.arm.count = 1
gate.trigger.count				= 1
-- arm sweep indica quanto sweep deve fare 
drain.trigger.arm.stimulus		= 0
--dico quali timer attivanzo le azioni

--event blender per la partenza
trigger.blender[1].orenable = true
trigger.blender[1].stimulus[1] = gate.trigger.ARMED_EVENT_ID
trigger.blender[1].stimulus[2] = drain.trigger.ARMED_EVENT_ID 

--dico quali stimoli/timer attivanzo le azioni
gate.trigger.source.stimulus = trigger.blender[1].EVENT_ID 
gate.trigger.measure.stimulus	= trigger.timer[2].EVENT_ID
--gate.trigger.endpulse.stimulus	= drain.trigger.SWEEP_COMPLETE_EVENT_ID
gate.trigger.endpulse.stimulus	= drain.trigger.IDLE_EVENT_ID

gate.trigger.source.action		= gate.ENABLE

-- Configure drain Trigger Model for Sweep

if source_drain==1 then------------------------
drain.trigger.source.linearv(start_drain, stop_drain, numPoints)
drain.trigger.source.limiti		= limiti_drain
else---------------------------------------------
drain.trigger.source.lineari(start_drain, stop_drain, numPoints)
drain.trigger.source.limitv		= limiti_drain
end---------------------------------------------
drain.trigger.measure.action		= drain.ENABLE
drain.trigger.measure.iv(drain.nvbuffer1, drain.nvbuffer2)
--fine impulso: se voglio una dc sweep, anzichè mandare in idle l'uscita, la tengo costante
drain.trigger.endpulse.action	= drain.SOURCE_HOLD 
-- endsweep mi dice cosa fare quando finisce l'operazione sweep
drain.trigger.endsweep.action	= drain.SOURCE_HOLD
drain.trigger.arm.count = 1
-- num punti sweep
drain.trigger.count				= numPoints
-- arm sweep indica quanto sweep deve fare
drain.trigger.arm.stimulus		= 0
--dico quali timer attivanzo le azioni
drain.trigger.source.stimulus	= trigger.timer[1].EVENT_ID
drain.trigger.measure.stimulus	= trigger.timer[2].EVENT_ID
drain.trigger.endpulse.stimulus	= trigger.timer[3].EVENT_ID
drain.trigger.source.action		= drain.ENABLE
--==============================
-- End Trigger Model Configuration

-- Start the trigger model execution
gate.trigger.initiate()
delay(0.05)
drain.trigger.initiate()

-- Wait until the sweep has completed
waitcomplete()


-- Configure gate Trigger Model for Sweep
-- imposto un singolo valore di tensione, costante per tutta la durata della sweep.
-- quindi quello che ottengo è la sweep di un singolo valore. il risultato è appunto una valore costante
if source_gate==1 then-----------------------
gate.trigger.source.listv({livello_gate[i]})
gate.trigger.source.limiti		= limiti_gate
else -------------------------------------------
gate.trigger.source.listi({livello_gate[i]})
gate.trigger.source.limitv		= limiti_gate
end--------------------------------------------
gate.trigger.measure.action		= gate.ASYNC
gate.trigger.measure.iv(gate.nvbuffer1, gate.nvbuffer2)
--fine impulso: se voglio una dc sweep, anzichè mandare in idle l'uscita, la tengo costante
gate.trigger.endpulse.action	= gate.SOURCE_HOLD
-- endsweep mi dice cosa fare quando finisce l'operazione sweep
gate.trigger.endsweep.action	= gate.SOURCE_HOLD
gate.trigger.arm.count = 1
gate.trigger.count				= 1
-- arm sweep indica quanto sweep deve fare 
drain.trigger.arm.stimulus		= 0
--dico quali timer attivanzo le azioni

--event blender per la partenza
trigger.blender[1].orenable = true
trigger.blender[1].stimulus[1] = gate.trigger.ARMED_EVENT_ID
trigger.blender[1].stimulus[2] = drain.trigger.ARMED_EVENT_ID 

--dico quali stimoli/timer attivanzo le azioni
gate.trigger.source.stimulus = trigger.blender[1].EVENT_ID 
gate.trigger.measure.stimulus	= trigger.timer[2].EVENT_ID
--gate.trigger.endpulse.stimulus	= drain.trigger.SWEEP_COMPLETE_EVENT_ID
gate.trigger.endpulse.stimulus	= drain.trigger.IDLE_EVENT_ID

--gate.trigger.source.action		= gate.ENABLE

-- Configure drain Trigger Model for Sweep

if source_drain==1 then------------------------
drain.trigger.source.linearv(stop_drain, start_drain, numPoints)
drain.trigger.source.limiti		= limiti_drain
else---------------------------------------------
drain.trigger.source.lineari(stop_drain, start_drain, numPoints)
drain.trigger.source.limitv		= limiti_drain
end---------------------------------------------
drain.trigger.measure.action		= drain.ENABLE
drain.trigger.measure.iv(drain.nvbuffer1, drain.nvbuffer2)
--fine impulso: se voglio una dc sweep, anzichè mandare in idle l'uscita, la tengo costante
drain.trigger.endpulse.action	= drain.SOURCE_HOLD 
-- endsweep mi dice cosa fare quando finisce l'operazione sweep
drain.trigger.endsweep.action	= drain.SOURCE_HOLD
drain.trigger.arm.count = 1
-- num punti sweep
drain.trigger.count				= numPoints
-- arm sweep indica quanto sweep deve fare
drain.trigger.arm.stimulus		= 0
--dico quali timer attivanzo le azioni
drain.trigger.source.stimulus	= trigger.timer[1].EVENT_ID
drain.trigger.measure.stimulus	= trigger.timer[2].EVENT_ID
drain.trigger.endpulse.stimulus	= trigger.timer[3].EVENT_ID
--drain.trigger.source.action		= drain.ENABLE
--==============================
-- End Trigger Model Configuration

-- Start the trigger model execution
gate.trigger.initiate()
--delay(0.05)
drain.trigger.initiate()
waitcomplete()
end

drain.source.output				= drain.OUTPUT_OFF
delay(0.05)
gate.source.output				= gate.OUTPUT_OFF

--printbuffer(1, numPoints, gate.nvbuffer2.readings)
--printbuffer(1, numPoints, gate.nvbuffer1.readings)
--printbuffer(1, numPoints, gate.nvbuffer1.timestamps)

--printbuffer(1, numPoints, drain.nvbuffer2.readings)
--printbuffer(1, numPoints, drain.nvbuffer1.readings)
--printbuffer(1, numPoints, drain.nvbuffer1.timestamps)