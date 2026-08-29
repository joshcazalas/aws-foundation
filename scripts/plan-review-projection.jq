{
  resource_changes: [
    .resource_changes[]?
    | select(.change.actions != ["no-op"])
    | select(.change.actions != ["read"])
    | {
        address,
        mode,
        type,
        name,
        provider_name,
        index,
        deposed,
        change
      }
  ]
  | sort_by(.address, (.deposed // "")),
  output_changes: (
    .output_changes // {}
    | to_entries
    | map(select(.value.actions != ["no-op"]))
    | sort_by(.key)
  )
}
