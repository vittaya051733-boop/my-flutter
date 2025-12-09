package sk.fourq.otaupdate.provider

import androidx.core.content.FileProvider

// Thin wrapper to satisfy the ota_update manifest provider when the upstream class is missing.
class GenericFileProvider : FileProvider()
