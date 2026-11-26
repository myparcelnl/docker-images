<?php

declare(strict_types=1);

namespace MyParcelNL\DevSeed\Observer;

use Magento\Framework\Event\Observer;
use Magento\Framework\Event\ObserverInterface;
use MyParcelNL\DevSeed\Model\SeedOrderContext;

/**
 * Stops the new order email for orders that the seed places (sales_model_service_quote_submit_before).
 * Magento's SubmitObserver sends that email only when the order allows it.
 */
class DisableSeedOrderEmail implements ObserverInterface
{
    public function __construct(private readonly SeedOrderContext $context)
    {
    }

    public function execute(Observer $observer): void
    {
        if ($this->context->isActive()) {
            $observer->getEvent()->getOrder()->setCanSendNewEmailFlag(false);
        }
    }
}
