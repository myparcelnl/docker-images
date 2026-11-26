<?php

declare(strict_types=1);

// Empty stand-ins for the Magento base classes that Config and Carrier extend, so the plugin's
// DeliveryCosts can be loaded on the host without a Magento install. Only loaded when Magento is absent.

namespace Magento\Framework\App\Helper {
    if (! class_exists(AbstractHelper::class)) {
        abstract class AbstractHelper
        {
        }
    }
}

namespace Magento\Shipping\Model\Carrier {
    if (! class_exists(AbstractCarrier::class)) {
        abstract class AbstractCarrier
        {
        }
    }

    if (! interface_exists(CarrierInterface::class)) {
        interface CarrierInterface
        {
        }
    }
}
