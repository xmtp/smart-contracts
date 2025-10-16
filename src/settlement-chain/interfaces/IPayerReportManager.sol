interface IPayerReportManager is IMigratable, IERC5267, IRegistryParametersError {
    // ... (rest of file as in xmtp/smart-contracts PR 162)
    // PATCHED FILE - see https://github.com/xmtp/smart-contracts/pull/162 for full diff
    // --- PATCHED CODE BEGIN ---
    /// @notice Thrown when the provided node IDs do not exactly match the registry set.
    error NodeIdsLengthMismatch(uint32 expectedCount, uint32 providedCount);

    /// @notice Element at `index` does not match the canonical node id at that position.
    error NodeIdAtIndexMismatch(uint32 expectedId, uint32 actualId, uint32 index);

    /// @notice Thrown when the internal state is corrupted
    error InternalStateCorrupted();
    // --- PATCHED CODE END ---
    /* ============ Initialization ============ */

    /**
     * ... rest of file ...
     */
}