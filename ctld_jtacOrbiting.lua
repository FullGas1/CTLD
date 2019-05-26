--  Automatic put in orbit of a  flying JTAC (IA) (example a drone) (FullGas le 24/5/2019)
--
--  Objective   : this script put in orbit 1 or more apparatus IA near a detected target
--                  Associated with CTLD/JTAC function, we can assign a fly route to a drone for example,
--                  this on follow it, and start orbiting when he detect a target.
--                  As soon as it don't detect a target, it restart following its route
--  Use : In mission editor:
--      			1> Charge MIST + CTLD
--                  2> Create a TRIGGER (once) at Time sup à 6, and a ACTION.EXECUTE SCRIPT :
--							ctld.JTACAutoLase("gdrone1", 1688,false)  -- défine group "gdrone1" as a JTAC
--							ctld.TreatOrbitJTAC()		      -- run automatic treating of JTACs orbiting

ctld.OrbitInUse = {}	    -- for each Orbit group in use, indicates the time of the run
------------------------------------------------------------------------------------
-- Automatic JTAC orbit on target detect
function ctld.TreatOrbitJTAC()			
	for k,v in pairs(ctld.jtacUnits) do					-- vérify state of each active JTAC
		if ctld.jtacCurrentTargets[k] ~= nil then		-- if detected target by JTAC
			if ctld.InOrbitList(k) == false then		-- JTAC have a target but isn't in orbit => put it in orbit
				ctld.StartOrbitGroup(k, ctld.jtacCurrentTargets[k].name, 2000, 100)	-- do orbit JTAC
				ctld.OrbitInUse[k] =  timer.getTime()								-- memorise time of start new orbiting
            else														-- JTAC already is orbiting => update coord for following the target mouvements
                if timer.getTime() > (ctld.OrbitInUse[k] + 60) then   	-- each 60" update orbit coord 
                    ctld.AjustRoute(k, ctld.NearWP(ctld.jtacCurrentTargets[k].name, k))  -- ajust JTAC route for the orbit follow the target
                end
			end
		elseif ctld.jtacCurrentTargets[k] == nil then			-- if JTAC hav no target
            if ctld.InOrbitList(k) == true then					-- JTAC orbiting, without target => stop orbit
				Group.getByName(k):getController():resetTask()	-- stop orbit JTAC
				ctld.OrbitInUse[k] =  nil						-- Reset orbit
			end
        end
	end
    mist.scheduleFunction(ctld.TreatOrbitJTAC, {}, timer.getTime()+3)		-- re-run each 3" 	
end
------------------------------------------------------------------------------------
-- Make orbit the group "_grpName", on target "_unitTargetName".  _alti in meters, speed in km/h
function ctld.StartOrbitGroup(_grpName, _unitTargetName, _alti, _speed)	
	if (Unit.getByName(_unitTargetName) ~= nil) and (Group.getByName(_grpName) ~= nil) then			-- si target unit and JTAC group exist
		local orbit = {
		   id = 'Orbit', 
			 params = { 
			   pattern = 'Circle',
			   point = mist.utils.makeVec2(mist.getAvgPos(mist.makeUnitTable({_unitTargetName}))),
			   speed = _speed,
			   altitude = _alti,
		   } 
		 }
		 Group.getByName(_grpName):getController():pushTask(orbit)
		 ctld.OrbitInUse[_grpName] = true
	 end
end
-------------------------------------------------------------------------------------------
-- test if one unitName already is targeted by a JTAC
function ctld.InOrbitList(_grpName)
    for k, v in pairs(ctld.OrbitInUse) do			-- for each orbit in use
		if k == _grpName then 
			return true
		end
	end 
	return false
end
-------------------------------------------------------------------------------------------
-- return the WayPoint number (on the JTAC route) the most near from the target 
function ctld.NearWP(_unitTargetName, _grpName)
    local WP = 0
    local memoDist = nil	-- Lower distance checked
    local JTACRoute = mist.getGroupRoute (_grpName, true)   -- get the initial editor route of the current group

        if Group.getByName(_grpName):getUnit(1) ~= nil and Unit.getByName(_unitTargetName) ~= nil then	--JTAC et unit must exist
            for i=1, #JTACRoute do
             	local ptJTAC   = {x = JTACRoute[i].x, y = JTACRoute[i].y}
                local ptTarget = mist.utils.makeVec2(Unit.getByName(_unitTargetName):getPoint())
                local dist = mist.utils.get2DDist(ptJTAC, ptTarget)		-- distance between 2 points
		        if memoDist == nil then
                    memoDist = dist
                    WP = i
                elseif dist < memoDist then
                    memoDist = dist
                    WP = i
                end
            end
        end
    return WP
end
----------------------------------------------------------------------------
-- Modify the route deleting all the WP before "firstWP" param, for aligne the orbit on the nearest WP of the target
function ctld.AjustRoute(_grpName, firstWP)
    local JTACRoute = mist.getGroupRoute (_grpName, true)   -- get the initial editor route of the current group
	for i=0, #JTACRoute-1 do
       	if firstWP+i <= #JTACRoute then
        	JTACRoute[i+1] = JTACRoute[firstWP+i]		-- replace keeped WP at start of new route
        else 
            JTACRoute[i+1] = nil						-- delete useless WP
        end
    end
     
	local Mission = {} 	
    Mission = { 
                id = 'Mission', 
                 params = { 
                           route = {points = JTACRoute
                				   }
            			  }
               } 
    -- unactive orbit mode if it's on
    if ctld.InOrbitList(_grpName) == true then					-- if JTAC orbiting => stop it
    	Group.getByName(_grpName):getController():resetTask()	-- stop JTAC orbiting
        ctld.OrbitInUse[_grpName] =  nil
    end
    
    Group.getByName(_grpName):getController():setTask(Mission)	-- submit the new route
	return Mission
end
----------------------------------------------------------------------------
-- tests
--return ctld.NearWP('BTR_2__1', 'gdrone2')
--return mist.utils.tableShow(ctld.AjustRoute('gdrone2', ctld.NearWP('BTR_2__1', 'gdrone2')))
--return ctld.NearWP('BTR_2__1', 'gdrone2')


