<?php

declare(strict_types=1);

namespace App\Controller;

class ControllerOverhead
{
	public function fibonacci($number)
	{
		if($number==0)
			return 0;
		elseif($number==1)
			return 1;
		else
			return ($this->fibonacci($number-1)+$this->fibonacci($number-2));
	}
	public function stress()
	{
		$time=microtime(true);
		$fibonacci=$this->fibonacci(40);
		$data=[
			'time'=>microtime(true)-$time,
			'fibonacci'=>$fibonacci,
		];
		return $data;
	}
	public function data()
	{
		$time=microtime(true);
		$content='data';
		$data=[
			'time'=>microtime(true)-$time,
			'content'=>$content,
		];
		return $data;
	}
}
