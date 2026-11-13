extends Node
## Global signal hub (autoload: EventBus).
## Decouples systems: emitters and listeners never reference each other.
## Only add signals that more than one independent system needs.

## Emitted when the selection changes. An empty id means nothing is selected.
@warning_ignore("unused_signal")
signal object_selected(object_id: String)

## Short message for the operator. severity is &"info" or &"warning".
@warning_ignore("unused_signal")
signal feedback_message_requested(message: String, severity: StringName)

## A new observation was recorded for a vessel (see ReactionEngine).
@warning_ignore("unused_signal")
signal observation_added(object_id: String, entry: Dictionary)

## A command was executed or rejected. The entry is the command-log record.
@warning_ignore("unused_signal")
signal command_logged(entry: Dictionary)

## A reference card should be pinned into the classroom dashboard overlay.
@warning_ignore("unused_signal")
signal reference_pin_requested(reference: Dictionary)
