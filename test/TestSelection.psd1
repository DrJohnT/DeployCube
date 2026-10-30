@{
    # Exact paths: never discover the legacy live-server tests in test/ recursively.
    UnitPaths = @(
        'Unit'
        'BoundedProcess.Tests.ps1'
        'DeploymentToolSelection.Tests.ps1'
        'DeploymentUtilityCompatibility.Tests.ps1'
        'MultidimensionalMetadata.Tests.ps1'
        'SqlServerMedia.Tests.ps1'
        'SqlServerMediaDownload.Tests.ps1'
        'SsasProcessingEvidence.Tests.ps1'
        'SsasProvisioningVerification.Tests.ps1'
        'TabularProcessingEvidence.Tests.ps1'
    )
    # All public module scripts, including external-boundary functions exercised using mocks.
    # Provisioning/install/deployment harnesses under test/infrastructure are NOT module unit coverage.
    CoveragePath = 'DeployCube/public/*.ps1'
    MinimumCoverage = 75
}
