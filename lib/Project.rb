#
# Project.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'TjTime'
require 'Booking'
require 'PropertySet'
require 'AllocationAttribute'
require 'BookingListAttribute'
require 'BooleanAttribute'
require 'DateAttribute'
require 'DependencyListAttribute'
require 'DurationAttribute'
require 'FlagListAttribute'
require 'FloatAttribute'
require 'FixnumAttribute'
require 'IntervalListAttribute'
require 'LimitsAttribute'
require 'ReferenceAttribute'
require 'StringAttribute'
require 'ShiftAssignmentsAttribute'
require 'TaskListAttribute'
require 'ResourceListAttribute'
require 'WorkingHoursAttribute'
require 'RealFormat'
require 'PropertyList'
require 'TaskDependency'
require 'Scenario'
require 'Shift'
require 'Account'
require 'Task'
require 'Resource'
require 'Report'
require 'ShiftAssignments'
require 'WorkingHours'
require 'ProjectFileParser'

# This class implements objects that hold all project properties. Project
# generally consist of resources, tasks and a number of other optional
# properties. Tasks, Resources, Accounts and Shifts are all build on the same
# underlying storage class PropertyTreeNode.
class Project

  attr_reader :tasks, :resources, :scenarios, :messageHandler

  # Create a project with the specified _id_, _name_ and _version_.
  # _messageHandler_ is a MessageHandler reference that is used to handle all
  # error and warning messages that might occur during processing. The
  # constructor will set default values for all project attributes.
  def initialize(id, name, version, messageHandler)
    @messageHandler = messageHandler
    @attributes = {
      'id' => id,
      'name' => name,
      'version' => version,
      'copyright' => nil,
      'currency' => "EUR",
      'currencyformat' => RealFormat.new([ '-', '', '', ',', 2 ]),
      'dailyworkinghours' => 8.0,
      'end' => nil,
      'flags' => [],
      'loadunit' => :shortauto,
      'now' => TjTime.now,
      'numberformat' => RealFormat.new([ '-', '', '', '.', 1]),
      'priority' => 500,
      'rate' => 0.0,
      'scheduleGranularity' => 3600,
      'shorttimeformat' => "%H:%M",
      'start' => nil,
      'timeformat' => "%Y-%m-%d",
      'timezone' => nil,
      'vacations' => [],
      'weekstartsmonday' => true,
      'workinghours' => WorkingHours.new,
      'yearlyworkingdays' => 260.714
    }

    @scenarios = PropertySet.new(self, true)
    attrs = [
      # ID           Name          Type               Inh.     Scen.  Default
      [ 'enabled',   'Enabled',    BooleanAttribute,  true,    false, true ],
      [ 'projection', 'Projection Mode', BooleanAttribute, true, false, false ],
      [ 'strict', 'Strict Bookings', BooleanAttribute, true, false, false ]
    ]
    attrs.each { |a| @scenarios.addAttributeType(AttributeDefinition.new(*a)) }

    @shifts = PropertySet.new(self, true)
    attrs = [
      # ID           Name            Type               Inher. Scen.  Default
      [ 'index',     'Index',        FixnumAttribute,   false, false, -1 ],
      [ 'replace',   'Replace',      BooleanAttribute,  true,  true,  false ],
      [ 'timezone',  'Time Zone',    StringAttribute,   true,  true,  nil ],
      [ 'tree',      'Tree Index',   StringAttribute,   false, false, "" ],
      [ 'vacations', 'Vacations',    IntervalListAttribute, true, true, [] ],
      [ 'wbs',       'WBS',          StringAttribute,   false, false, "" ],
      [ 'workinghours', 'Working Hours', WorkingHoursAttribute, true, true,
        nil ]
    ]
    attrs.each { |a| @shifts.addAttributeType(AttributeDefinition.new(*a)) }

    @accounts = PropertySet.new(self, true)
    attrs = [
      # ID           Name            Type               Inher. Scen.  Default
      [ 'index',     'Index',        FixnumAttribute,   false, false, -1 ],
      [ 'tree',      'Tree Index',   StringAttribute,   false, false, "" ],
      [ 'wbs',       'WBS',          StringAttribute,   false, false, "" ]
    ]
    attrs.each { |a| @accounts.addAttributeType(AttributeDefinition.new(*a)) }

    @resources = PropertySet.new(self, true)
    attrs = [
      # ID           Name            Type               Inher. Scen.  Default
      [ 'alloctdeffort', 'Alloctd. Effort', FloatAttribute, false, true, 0.0 ],
      [ 'criticalness', 'Criticalness', FloatAttribute, false, true, 0.0 ],
      [ 'duties',    'Duties',       TaskListAttribute, false, true,  [] ],
      [ 'efficiency','Efficiency',   FloatAttribute,    true,  true, 1.0 ],
      [ 'effort', 'Total Effort',    FixnumAttribute,   false, true, 0 ],
      [ 'email',     'Email',        StringAttribute,   true,  false, nil ],
      [ 'flags',     'Flags',        FlagListAttribute, true,  true,  [] ],
      [ 'fte',       'FTE',          FloatAttribute,    false,  true, 1.0 ],
      [ 'headcount', 'Headcount',    FixnumAttribute,   false,  true, 1 ],
      [ 'index',     'Index',        FixnumAttribute,   false, false, -1 ],
      [ 'limits',    'Limits',       LimitsAttribute,   true,  true, nil ],
      [ 'rate',      'Rate',         FloatAttribute,    true,  true, 0.0 ],
      [ 'shifts',    'Shifts',       ShiftAssignmentsAttribute, true, true,
        nil ],
      [ 'timezone',  'Time Zone',    StringAttribute,   true,  true,  nil ],
      [ 'tree',      'Tree Index',   StringAttribute,   false, false, "" ],
      [ 'vacations',  'Vacations',   IntervalListAttribute, true, true, [] ],
      [ 'wbs',       'WBS',          StringAttribute,   false, false, "" ],
      [ 'workinghours', 'Working Hours', WorkingHoursAttribute, true, true,
        nil ]
    ]
    attrs.each { |a| @resources.addAttributeType(AttributeDefinition.new(*a)) }

    @tasks = PropertySet.new(self, false)
    attrs = [
      # ID           Name            Type               Inher. Scen.  Default
      [ 'allocate', 'Allocations', AllocationAttribute, true,  true,  [] ],
      [ 'assignedresources', 'Assigned Resources', ResourceListAttribute, false, true, [] ],
      [ 'bookedresources', 'Booked Resources', ResourceListAttribute, false, true, [] ],
      [ 'booking',   'Bookings',     BookingListAttribute, false, true, [] ],
      [ 'complete',  'Completion',   FloatAttribute,    false, true,  nil ],
      [ 'criticalness', 'Criticalness', FloatAttribute, false, true,  0.0 ],
      [ 'depends',   '-',      DependencyListAttribute, true,  true,  [] ],
      [ 'duration',  'Duration',     DurationAttribute, false, true,  0.0 ],
      [ 'effort',    'Effort',       DurationAttribute, false, true,  0.0 ],
      [ 'end',       'End',          DateAttribute,     true,  true,  nil ],
      [ 'endcredit', 'End Credit',   FloatAttribute,    false, true,  0.0 ],
      [ 'endpreds',  'End Preds.',   TaskListAttribute, false, true,  [] ],
      [ 'endsuccs',  'End Succs.',   TaskListAttribute, false, true,  [] ],
      [ 'flags',     'Flags',        FlagListAttribute, true,  true,  [] ],
      [ 'forward',   'Scheduling',   BooleanAttribute,  true,  true,  true ],
      [ 'index',     'Index',        FixnumAttribute,   false, false, -1 ],
      [ 'length',    'Length',       DurationAttribute, false, true,  0.0 ],
      [ 'limits',    'Limits',       LimitsAttribute,   false, true,  nil ],
      [ 'maxend',    'Max. End',     DateAttribute,     true,  true,  nil ],
      [ 'maxstart',  'Max. Start',   DateAttribute,     true,  true,  nil ],
      [ 'milestone', 'Milestone',    BooleanAttribute,  false, true,  false ],
      [ 'minend',    'Min. End',     DateAttribute,     true,  true,  nil ],
      [ 'minstart',  'Min. Start',   DateAttribute,     true,  true,  nil ],
      [ 'note',      'Note',         StringAttribute,   false, false, nil ],
      [ 'pathcriticalness', 'Path Criticalness', FloatAttribute, false, true, 0.0 ],
      [ 'precedes',  '-',      DependencyListAttribute, true,  true,  [] ],
      [ 'priority',  'Priority',     FixnumAttribute,   true,  true,  500 ],
      [ 'responsible', 'Responsible', ResourceListAttribute, true, true, [] ],
      [ 'scheduled', 'Scheduled',    BooleanAttribute,  true,  true,  false ],
      [ 'shifts',     'Shifts',      ShiftAssignmentsAttribute, true, true,
        nil ],
      [ 'start',     'Start',        DateAttribute,     true,  true,  nil ],
      [ 'startcredit', 'Start Credit', FloatAttribute,  false, true,  0.0 ],
      [ 'startpreds', 'Start Preds.', TaskListAttribute, false, true, [] ],
      [ 'startsuccs', 'Start Succs.', TaskListAttribute, false, true, [] ],
      [ 'tree',      'Tree Index',   StringAttribute,   false, false, "" ],
      [ 'wbs',       'WBS',          StringAttribute,   false, false, "" ]
    ]
    attrs.each { |a| @tasks.addAttributeType(AttributeDefinition.new(*a)) }

    Scenario.new(self, 'plan', 'Plan Scenario', nil)

    @reports = []
  end

  def sendMessage(message)
    @messageHandler.send(message)
  end

  def [](name)
    if !@attributes.has_key?(name)
      raise "Unknown project attribute #{name}"
    end
    @attributes[name]
  end

  def []=(name, value)
    if !@attributes.has_key?(name)
      raise "Unknown project attribute #{name}"
    end
    @attributes[name] = value
  end

  def scenarioCount
    @scenarios.items
  end

  def dailyWorkingHours
    @attributes['dailyworkinghours']
  end

  def weeklyWorkingDays
    @attributes['yearlyworkingdays'] / 52.1429
  end

  def monthlyWorkingDays
    @attributes['yearlyworkingdays'] / 12
  end

  def yearlyWorkingDays
    @attributes['yearlyworkingdays']
  end

  def scenario(arg)
    if arg.class == Fixnum
      if $DEBUG && (arg < 0 || arg >= @scenarios.items)
        raise "Scenario index out of range: #{arg}"
      end
      @scenarios.each do |sc|
        return sc if sc.sequenceNo - 1 == arg
      end
      raise "No scenario with index #{arg}"
    else
      if $DEBUG && @scenarios[arg].nil?
        raise "No scenario with id '#{arg}'"
      end
      @scenarios[arg]
    end
  end

  def scenarioIdx(sc)
    if sc.is_a?(Scenario)
      return sc.sequenceNo - 1
    elsif @scenarios[sc].nil?
      return nil
    else
      return @scenarios[sc].sequenceNo - 1
    end
  end

  def shift(id)
    @shifts[id]
  end

  def account(id)
    @accounts[id]
  end

  def task(id)
    @tasks[id]
  end

  def resource(id)
    @resources[id]
  end

  def schedule
    [ @shifts, @resources, @tasks ].each do |p|
      p.inheritAttributesFromScenario
      # Set all index counters to their proper values.
      p.index
    end

    begin
      @scenarios.each do |sc|
        # Skip disabled scenarios
        next unless sc.get('enabled')

        scIdx = scenarioIdx(sc)

        # All user provided values are set now. The next step is to
        # propagate inherited values. These values must be marked as
        # inherited by setting the mode to 1. As we always call
        # PropertyTreeNode#inherit this is just a safeguard.
        AttributeBase.setMode(1)

        prepareScenario(scIdx)

        # Now change to mode 2 so all values that are modified are marked
        # as computed.
        AttributeBase.setMode(2)

        scheduleScenario(scIdx)
        finishScenario(scIdx)
      end
    rescue TjException
      return false
    end

    true
  end

  def generateReports
    begin
      @reports.each { |report| report.generate }
    rescue TjException
      $stderr.puts "Reporting Error: #{$!}"
      return false
    end

    true
  end

  ####################################################################
  # The following functions are not intended to be called from outside
  # the TaskJuggler library. There is no guarantee that these
  # functions will be usable or present in future releases.
  ####################################################################

  def addScenario(scenario) # :nodoc:
    @scenarios.addProperty(scenario)
  end

  def addShift(shift) # :nodoc:
    @shifts.addProperty(shift)
  end

  def addAccount(account) # :nodoc:
    @accounts.addProperty(account)
  end

  def addTask(task) # :nodoc:
    @tasks.addProperty(task)
  end

  def addResource(resource) # :nodoc:
    @resources.addProperty(resource)
  end

  def addReport(report) # :nodoc:
    @reports.push(report)
  end

  def isWorkingTime(*args)
    # Normalize argument(s) to Interval
    if args.length == 1
      if args[0].is_a?(Interval)
        iv = args[0]
      else
        iv = Interval.new(args[0], args[0] + @attributes['scheduleGranularity'])
      end
    else
      iv = Interval.new(args[0], args[1])
    end

    # Check if the interval has overlap with any of the global vacations.
    @attributes['vacations'].each do |vacation|
      return false if vacation.overlaps?(iv)
    end

    return false if @attributes['workinghours'].timeOff?(iv)

    true
  end

  def convertToDailyLoad(seconds)
    seconds / (@attributes['dailyworkinghours'] * 3600)
  end

  def scoreboardSize
    ((@attributes['end'] - @attributes['start']) /
     @attributes['scheduleGranularity']).to_i
  end

  def idxToDate(idx)
    if $DEBUG && (idx < 0 || idx > scoreboardSize)
      raise "Scoreboard index out of range"
    end
    @attributes['start'] + idx * @attributes['scheduleGranularity']
  end

  def dateToIdx(date, forceIntoProject = false)
    if (date < @attributes['start'] || date > @attributes['end'])
      if forceIntoProject
        return 0 if date < @attributes['start']
        return scoreboardSize if date > @attributes['end']
      else
        raise "Date #{date} is out of project time range " +
              "(#{@attributes['start']} - #{@attributes['end']})"
      end
    end
    ((date - @attributes['start']) / @attributes['scheduleGranularity']).to_i
  end

protected

  def prepareScenario(scIdx)
    resources = PropertyList.new(@resources)
    tasks = PropertyList.new(@tasks)

    resources.each do |resource|
      resource.prepareScheduling(scIdx)
    end
    tasks.each do |task|
      task.prepareScheduling(scIdx)
    end

    tasks.each do |task|
      task.Xref(scIdx)
    end
    tasks.each do |task|
      task.implicitXref(scIdx)
    end
    tasks.each do |task|
      task.propagateInitialValues(scIdx)
    end
    tasks.each do |task|
      task.preScheduleCheck(scIdx)
    end
    tasks.each do |task|
      task.resetLoopFlags(scIdx)
    end
    tasks.each do |task|
      task.checkForLoops(scIdx, [], false, true) if task.parent.nil?
    end
    tasks.each do |task|
      task.resetLoopFlags(scIdx)
    end
    tasks.each do |task|
      task.checkForLoops(scIdx, [], true, true) if task.parent.nil?
    end
    tasks.each do |task|
      task.checkDetermination(scIdx)
    end

    tasks.each do |task|
      task.countResourceAllocations(scIdx)
    end
    resources.each do |resource|
      resource.calcCriticalness(scIdx)
    end
    tasks.each do |task|
      task.calcCriticalness(scIdx)
    end
    tasks.each do |task|
      task.calcPathCriticalness(scIdx)
    end

    # This is used for debugging only
    if false
      resources.each do |resource|
        puts resource
      end
      tasks.each do |task|
        puts task
      end
    end
  end

  def finishScenario(scIdx)
    @tasks.each do |task|
      task.finishScheduling(scIdx)
    end

    @tasks.each do |task|
      task.postScheduleCheck(scIdx) if task.parent.nil?
    end
  end

  def scheduleScenario(scIdx)
    # The scheduler directly only cares for leaf tasks. These are put in the
    # allWorkItems list.
    allWorkItems = PropertyList.new(@tasks)
    allWorkItems.delete_if { |task| !task.leaf? }
    allWorkItems.setSorting([ [ 'priority', false, scIdx ],
                              [ 'pathcriticalness', false, scIdx ],
                              [ 'seqno', true, -1 ] ])

    # The main scheduler loop only needs to look at the tasks that are ready
    # to be scheduled.
    workItems = Array.new(allWorkItems)
	  workItems.delete_if { |task| !task.readyForScheduling?(scIdx) }

    @breakFlag = false
    loop do
      done = true
      slot = nil
      priority = 0
      pathCriticalness = 0.0
      forward = true

      workItems.each do |task|
        if slot.nil?
          slot = task.nextSlot(scIdx, @attributes['scheduleGranularity'])
          next if slot.nil?

          priority = task['priority', scIdx]
          pathCriticalness = task['pathcriticalness', scIdx]
          forward = task['forward', scIdx]

          if (slot < @attributes['start'] ||
              slot > @attributes['end'])
            task.markAsRunaway(scIdx)
            slot = nil
            next
          end
        end

        done = false

        break if (task['forward', scIdx] != forward &&
                  !task['milestone', scIdx]) ||
                 task['priority', scIdx] < priority ||
                 (task['priority', scIdx] == priority &&
                  task['pathcriticalness', scIdx] < pathCriticalness)

        if task.schedule(scIdx, slot, @attributes['scheduleGranularity'])
          # If one or more tasks have been scheduled completely, we
	        # recreate the list of all tasks that are ready to be scheduled.
          workItems = Array.new(allWorkItems)
          workItems.delete_if { |task| !task.readyForScheduling?(scIdx) }
          break
        end
      end

      break if done || @breakFlag
    end
  end

end

